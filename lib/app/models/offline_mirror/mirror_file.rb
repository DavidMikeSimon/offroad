module OfflineMirror
	#private
	
	class MirrorFile
		def self.create_up_mirror_for(group_id)
			f = MirrorFile.new
			f.set_standard_title("Uploadable")
			f.message = "<p>This is a " + OfflineMirror::app_name " data file for upload.</p>"
			f.message += "<p>Please use the website at <a href=\"" + OfflineMirror::online_url + "\">" + OnlineMirror::online_url + "</a> to upload it.</p>"
			f.save_to_tmp
		end
		
		def self.create_down_mirror_for(group_id)
		end
		
		def self.load_from(ioh)
		end
		
		def save_to_tmp
			# FIXME Come up with an actual random file name
			File.open(File.join(RAILS_ROOT, "tmp", "test")) do |ioh|
				write_to(ioh)
			end
		end
		
		def apply_to_database
		end
		
		private
		
		def initialize(ioh = nil)
			if ioh
				read(ioh)
			else
				@message = ""
				@title = ""
				
				@file_info = {
					:created_by => OfflineMirror::app_online? ? "Online App" : ("Offline App for Group " + OfflineMirror::offline_group_id),
					:created_at => Time.now,
					:online_site => OfflineMirror::online_url,
					:app => OfflineMirror::app_name,
					:app_version => OfflineMirror::app_version,
					:launcher_version => OfflineMirror::app_offline? ? OfflineMirror::launcher_version : "Online",
					:operating_system => RUBY_PLATFORM
				}
				
				@cargo_table = {:file_info => @file_info}
			end
		end
		
		attr_accessible :message, :title, :cargo_table
		
		def set_standard_title(mode)
			@title = OfflineMirror::app_name + " " + mode + " Data"
		end
		
		def clean_for_html_comment(s)
			s.replace("--", "__").replace("<","[").replace(">","]")
		end
		
		def write_to(ioh)
			ioh.p "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n"
			ioh.p "<!-- This file contains Offline Mirror data."
			@file_info.keys.map({ |k| [k.to_s, @file_info[k]] }).sort.each do |k, v|
				ioh.p clean_for_html_comment(k.titleize) + ": " + clean_for_html_comment(k)
			end
			ioh.p "-->"
			
			ioh.p "<html>"
			ioh.p "<head><title>" + @title + "</title></head>"
			ioh.p "<body>"
			ioh.p @message
			ioh.p "</body>"
			ioh.p "</html>"
			
			@cargo_table.each_pair do |k, v|
				name = Base64.b64encode(k)
				data = Base64.b64encode(Zlib::Deflate::deflate(v))
				verif = data.hash 
				
				ioh.p "<!-- CARGO SEGMENT"
				ioh.p "NAME:"
				ioh.p name
				ioh.p "VERIF:"
				ioh.p verif
				ioh.p "DATA:"
				ioh.p data
				ioh.p "-->"
			end
		end
		
		def read_from(ioh)
		end
	end
end
