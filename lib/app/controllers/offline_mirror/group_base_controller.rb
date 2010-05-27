module OfflineMirror
	class GroupBaseController < ApplicationController
		protected
		
		def render_up_mirror_file(group, filename, render_args = {})
			raise "Cannot generate up-mirror file when app in online mode" if OfflineMirror::app_online?
			render_appending_cargo_data(group, filename, render_args) do |cargo_streamer|
				write_group_specific_cargo(group, cargo_streamer)
			end
		end
		
		def render_down_mirror_file(group, filename, render_args = {})
			raise "Cannot generate down-mirror file when app in offline mode" if OfflineMirror::app_offline?
			render_appending_cargo_data(group, filename, render_args) do |cargo_streamer|
				# FIXME: Include an updated version of the app here, if one is available
				write_global_cargo(group, cargo_streamer)
				
				# If this group has no confirmed down mirror, also include all group data to be the offline app's initial state
				if group.group_state.down_mirror_version == 0
					write_group_specific_cargo(group, cargo_streamer)
				end
			end
		end
		
		private
		
		def write_group_specific_cargo(group, cargo_streamer)
			# FIXME: Make sure that when this is being called by the online app, it doesn't accidentally fill mirrored_records with group-specific junk
			# FIXME: Also allow for a full-sync mode (includes all records)
			OfflineMirror::group_owned_models.each do |name, cls|
				write_model_cargo(cargo_streamer, "group_model", cls, :conditions => { cls.offline_mirror_group_key.to_sym => group })
			end
			
			# Have to include the schema so all tables are available to pre-import migrations, even if we don't send any changes to this table
			cargo_streamer.write_cargo_section("group_model_schema_#{OfflineMirror::group_base_model.name}", OfflineMirror::group_base_model.columns)
			# FIXME: Check against mirror version; don't include if there are no changes
			cargo_streamer.write_cargo_section("group_model_data_#{OfflineMirror::group_base_model.name}", group.attributes)
		end
		
		def write_global_cargo(group, cargo_streamer)
			# FIXME: Indicate what down-mirror version this is
			# FIXME: Also allow for a full-sync mode (includes all records)
			OfflineMirror::global_data_models.each do |name, cls|
				write_model_cargo(cargo_streamer, "global_model", cls)
			end
		end
		
		def write_model_cargo(cargo_streamer, prefix, model, find_options = {})
			# FIXME: Also include id transformation by joining with the mirrored_records table
			# FIXME: Include entries for deleted records
			# FIXME: Check against mirror version
			cargo_streamer.write_cargo_section("#{prefix}_schema_#{model.name}", model.columns)
			model.find_in_batches(find_options.merge({:batch_size => 100})) do |batch|
				cargo_streamer.write_cargo_section("#{prefix}_data_#{model.name}", batch.map(&:attributes))
			end
		end
		
		def render_appending_cargo_data(group, filename, render_args)	
			# Encourage browser to download this to disk instead of displaying it
			headers['Content-Disposition'] = "attachment; filename=\"#{filename}\""
			
			orig_html = render_to_string render_args
			render :text => Proc.new { |response, output|
				output.write(orig_html)
				cargo_streamer = CargoStreamer.new(output, "w")	
				
				# FIXME: Is there some way to make sure this entire process occurs in a kind of read transaction?
				
				# These lines append standard information that should be included in every mirror file
				cargo_streamer.write_cargo_section("group_state", group.group_state.attributes)
				file_info = {
					"created_at" => Time.now,
					"online_site" => OfflineMirror::online_url,
					"app" => OfflineMirror::app_name,
					"app_mode" => OfflineMirror::app_online? ? "Online" : ("Offline for Group " + OfflineMirror::offline_group_id),
					"app_version" => OfflineMirror::app_version,
					"operating_system" => RUBY_PLATFORM,
					"for_group" => group.id,
					"plugin" => "Offline Mirror " + OfflineMirror::VERSION_MAJOR.to_s + "." + OfflineMirror::VERSION_MINOR.to_s
				}
				cargo_streamer.write_cargo_section("file_info", file_info, :human_readable => true)
				schema_migrations = OfflineMirror::group_base_model.connection.select_all("SELECT * FROM schema_migrations")
				cargo_streamer.write_cargo_section("schema_migrations", schema_migrations)
				
				yield cargo_streamer
			}
		end
	end
end
