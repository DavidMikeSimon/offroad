module OfflineMirror
	class GroupBaseController < ApplicationController
		protected
		
		def render_up_mirror_file(group, filename, render_args = {})
			raise "Cannot generate up-mirror file when app in online mode" if OfflineMirror::app_online?
			t = create_cargo_table(group)
			OfflineMirror::add_group_specific_mirror_cargo(group, t)
			render_appending_cargo_table(render_args, t, filename)
		end
		
		def render_down_mirror_file(group, filename, render_args = {})
			raise "Cannot generate down-mirror file when app in offline mode" if OfflineMirror::app_offline?
			t = create_cargo_table(group)
			OfflineMirror::add_global_mirror_cargo(group, t)
			render_appending_cargo_table(render_args, t, filename)
		end
		
		private
		
		def create_cargo_table(group)
			t = CargoTable.new
			t["file_info"] = {
				"created_by" => OfflineMirror::app_online? ? "Online App" : ("Offline App for Group " + OfflineMirror::offline_group_id),
				"created_at" => Time.now,
				"online_site" => OfflineMirror::online_url,
				"app" => OfflineMirror::app_name,
				"app_version" => OfflineMirror::app_version,
				"operating_system" => RUBY_PLATFORM,
				"for_group" => group.id,
				"plugin" => "Offline Mirror " + OfflineMirror::VERSION_MAJOR.to_s + "." + OfflineMirror::VERSION_MINOR.to_s
			}
			return t
		end
		
		def render_appending_cargo_table(render_args, cargo_table, filename)
			data = (render_to_string render_args) + (cargo_table.write_to_string)
			send_data data, :filename => filename
		end
	end
end
