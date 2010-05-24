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
				# FIXME: Include an updated version of the app here, if necessary
				write_global_cargo(group, cargo_streamer)
			end
		end
		
		private
		
		def write_group_specific_cargo(group, cargo_streamer)
			# FIXME: Is there some way to make sure this entire process occurs in a kind of read transaction?
			# FIXME: Indicate what up-mirror version this is, and what migrations are applied
			# FIXME: Also allow for a full-sync mode (includes all records)
			OfflineMirror::group_owned_models.each do |name, cls|
				cargo_streamer.write_cargo_section("group_model_schema_#{name}", cls.columns)
				
				# FIXME: Also include id transformation by joining with the mirrored_records table
				# FIXME: Check against mirror version
				# FIXME: Mark deleted records
				data = cls.find(:all, :conditions => { cls.offline_mirror_group_key.to_sym => group })
				cargo_streamer.write_cargo_section("group_model_data_#{name}", data.map(&:attributes))
			end
			
			cargo_streamer.write_cargo_section("group_state", group.group_state.attributes)
			
			# Have to include the schema so all tables are available to pre-import migrations, even if we don't send any changes to this table
			cargo_streamer.write_cargo_section("group_model_schema_#{OfflineMirror::group_base_model.name}", OfflineMirror::group_base_model.columns)
			# FIXME: Check against mirror version; don't include if there are no changes
			cargo_streamer.write_cargo_section("group_model_data_#{OfflineMirror::group_base_model.name}", group.attributes)
		end
		
		def write_global_cargo(group, cargo_streamer)
			# FIXME: Is there some way to make sure this entire process occurs in a kind of read transaction?
			# FIXME: Indicate what down-mirror version this is
			# FIXME: Also allow for a full-sync mode (includes all records)
			OfflineMirror::global_data_models.each do |name, cls|
				cargo_streamer.write_cargo_section("global_model_schema_#{name}", cls.columns)
				# No need to worry about id transformation global data models, it's not necessary
				# FIXME: Check against mirror version
				# FIXME: Mark deleted records
				cargo_streamer.write_cargo_section("global_model_data_#{name}", cls.all.map(&:attributes))
			end
			
			# If this group has no confirmed down mirror, also include all group data to be the offline app's initial state
			if group.group_state.down_mirror_version == 0
				write_group_specific_cargo(group, cargo_streamer)
			end
		end
		
		def render_appending_cargo_data(group, filename, render_args)
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
			
			orig_html = render_to_string render_args
			render :text => Proc.new { |response, output|
				# Encourage browser to download this to disk instead of displaying it
				response.header['Content-Disposition'] = "attachment; filename=\"#{filename}\""
				
				output.write(orig_html)
				cargo_streamer = CargoStreamer.new(output, "w")
				cargo_streamer.write_cargo_section("file_info", file_info, :human_readable => true)
				yield cargo_streamer
			}
		end
	end
end
