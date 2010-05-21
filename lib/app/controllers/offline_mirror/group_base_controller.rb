module OfflineMirror
	class GroupBaseController < ApplicationController
		protected
		
		def render_up_mirror_file(group, filename, render_args = {})
			raise "Cannot generate up-mirror file when app in online mode" if OfflineMirror::app_online?
			f = create_mirror_file(group)
			# TODO Add up mirror data
			render_appending_cargo_file(render_args, f, filename)
		end
		
		def render_down_mirror_file(group, filename, render_args = {})
			raise "Cannot generate down-mirror file when app in offline mode" if OfflineMirror::app_offline?
			f = create_mirror_file(group)
			# TODO Add down mirror data
			render_appending_cargo_file(render_args, f, filename)
		end
		
		private
		
		def create_mirror_file(group)
			f = CargoFile.new
			f.cargo_table[:file_info] = {
				"created_by" => OfflineMirror::app_online? ? "Online App" : ("Offline App for Group " + OfflineMirror::offline_group_id),
				"created_at" => Time.now,
				"online_site" => OfflineMirror::online_url,
				"app" => OfflineMirror::app_name,
				"app_version" => OfflineMirror::app_version,
				"launcher_version" => OfflineMirror::app_offline? ? OfflineMirror::launcher_version : "Online",
				"operating_system" => RUBY_PLATFORM,
				"for_group" => group.id,
				"plugin" => "Offline Mirror " + OfflineMirror::VERSION_MAJOR.to_s + "." + OfflineMirror::VERSION_MINOR.to_s
			}
			return f
		end
		
		def render_appending_cargo_file(render_args, cargo_file, filename)
			data = (render_to_string render_args) + (cargo_file.write_to_string)
			send_data data, :filename => filename
		end
	end
end
