require 'zlib'

module OfflineMirror
	#private
	
	class MirrorFile
		# TODO Move this to the worker
		def self.create_up_mirror_for(group_id)
			f = MirrorFile.new(group_id)
			f.set_standard_title("Uploadable")
			f.message = "<p>This is a " + OfflineMirror::app_name + " data file for upload.</p>"
			f.message += "<p>Please use the website at <a href=\"" + OfflineMirror::online_url + "\">" + OfflineMirror::online_url + "</a> to upload it.</p>"
			return f
		end
		
		# TODO Move this to the worker
		def self.create_down_mirror_for(group_id)
		end
		
		def save_to_tmp
			# FIXME Come up with an actual random file name
			File.open(File.join(RAILS_ROOT, "tmp", "test"), "w") do |ioh|
				write_to(ioh)
			end
		end
		
		def apply_to_database
		end
		
		def initialize(group_id = nil)
			@message = ""
			@title = ""
			
			@file_info = {
				:created_by => OfflineMirror::app_online? ? "Online App" : ("Offline App for Group " + OfflineMirror::offline_group_id),
				:created_at => Time.now,
				:online_site => OfflineMirror::online_url,
				:app => OfflineMirror::app_name,
				:app_version => OfflineMirror::app_version,
				:launcher_version => OfflineMirror::app_offline? ? OfflineMirror::launcher_version : "Online",
				:operating_system => RUBY_PLATFORM,
				:for_group => group_id ? group_id : "Unknown"
			}
			
			@cargo_table = {:file_info => @file_info}
		end
		
		attr_accessor :message, :title, :cargo_table
		
		def set_standard_title(mode)
			@title = OfflineMirror::app_name + " " + mode + " Data"
		end
		
		def clean_for_html_comment(s)
			s.to_s.gsub("--", "__").gsub("<", "[").gsub(">", "]")
		end
		
		def write_to(ioh)
			ioh.puts "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n"
			ioh.puts "<!-- This file contains Offline Mirror data."
			@file_info.keys.map{ |k| [k.to_s, @file_info[k]] }.sort.each do |k, v|
				ioh.puts clean_for_html_comment(k.titleize) + ": " + clean_for_html_comment(v)
			end
			ioh.puts "-->"
			
			ioh.puts "<html>"
			ioh.puts "<head><title>" + @title + "</title></head>"
			ioh.puts "<body>"
			ioh.puts @message
			ioh.puts "</body>"
			ioh.puts "</html>"
			
			@cargo_table.each_pair do |k, v|
				name = k.to_s
				data = Base64.b64encode(Zlib::Deflate::deflate(v.to_json))
				
				ioh.puts "<!-- CARGO SEGMENT"
				ioh.puts name + ":"
				ioh.puts data.hash.to_s
				ioh.puts data
				ioh.puts "-->"
			end
		end
		
		def read_from(ioh)
		end
	end
end
