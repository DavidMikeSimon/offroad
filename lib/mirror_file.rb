require 'zlib'
require 'digest/md5'

module OfflineMirror
	class MirrorFileCorruptionError < RuntimeError
		def initialize(msg)
			super(msg)
		end
	end
	
	private
	
	class MirrorFile
		attr_accessor :message, :title, :css, :cargo_table
		
		def initialize(options = {})
			@cargo_table = {}
			@message = ""
			@title = ""
			@css = ""
			
			if options[:group_state]
				@cargo_table[:file_info] = {
					"created_by" => OfflineMirror::app_online? ? "Online App" : ("Offline App for Group " + OfflineMirror::offline_group_id),
					"created_at" => Time.now,
					"online_site" => OfflineMirror::online_url,
					"app" => OfflineMirror::app_name,
					"app_version" => OfflineMirror::app_version,
					"launcher_version" => OfflineMirror::app_offline? ? OfflineMirror::launcher_version : "Online",
					"operating_system" => RUBY_PLATFORM,
					"for_group" => options[:group_state].app_group_id
				}
			elsif options[:ioh]
				read_from(options[:ioh])
			else
				raise "Need to suppy either a :group_state option or an :ioh option to MirrorFile::new"
			end
		end
		
		# Returns a closed Tempfile which contains the cargo data.
		def save_to_tmp
			ioh = Tempfile.new("mirror_" + @cargo_table[:file_info]["for_group"].to_s + "_")
			write_to(ioh)
			ioh.close()
			return ioh
		end
		
		def set_standard_title(mode)
			@title = OfflineMirror::app_name + " " + mode + " Data"
		end
		
		def clean_for_html_comment(s)
			s.to_s.gsub("--", "__").gsub("<", "[").gsub(">", "]")
		end
		
		def write_to(ioh)
			ioh.puts "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n"
			ioh.puts "<!-- This file contains Offline Mirror data."
			@cargo_table[:file_info].keys.map{ |k| [k.to_s, @cargo_table[:file_info][k]] }.sort.each do |k, v|
				ioh.puts clean_for_html_comment(k.titleize) + ": " + clean_for_html_comment(v)
			end
			ioh.puts "-->"
			
			ioh.puts "<html>"
			ioh.puts "<head><style type=\"text/css\">" + @css + "</style><title>" + @title + "</title></head>"
			ioh.puts "<body>" + @message + "</body>"
			ioh.puts "</html>"
			
			cargo_to_include = @cargo_table.merge({:html_title => @title, :html_message => @message, :html_css => @css})
			cargo_to_include.each_pair do |k, v|
				name = k.to_s
				deflated_data = Zlib::Deflate::deflate(v.to_json)
				b64_data = Base64.encode64(deflated_data)
				digest = Digest::MD5::hexdigest(deflated_data)
				
				raise "Invalid cargo name '" + name + "'" unless name == clean_for_html_comment(name)
				
				ioh.puts CARGO_BEGIN 
				ioh.puts name
				ioh.puts digest
				ioh.puts b64_data
				ioh.puts CARGO_END
			end
		end
		
		private
		
		def read_from(ioh)
			in_cargo = false
			cargo_parts = {}
			ioh.each_line do |line|
				line.chomp!
				if in_cargo
					if !cargo_parts.has_key?(:name)
						cargo_parts[:name] = line
					elsif !cargo_parts.has_key?(:digest)
						cargo_parts[:digest] = line
					elsif line == CARGO_END
						import_cargo(cargo_parts[:name], cargo_parts[:digest], cargo_parts[:data])
						in_cargo = false
						cargo_parts = {}
					else
						cargo_parts[:data] = "" unless cargo_parts.has_key?(:data)
						cargo_parts[:data] += line
					end
				else
					in_cargo = true if line == CARGO_BEGIN
				end
			end
			
			raise MirrorFileCorruptionError.new("Mirror file contained un-terminated cargo section") unless in_cargo == false
		end
		
		def import_cargo(name, digest, b64_data)
			deflated_data = Base64.decode64(b64_data)
			raise "MD5 check failure" unless Digest::MD5::hexdigest(deflated_data) == digest
			data = ActiveSupport::JSON.decode(Zlib::Inflate::inflate(deflated_data))
			sym = name.to_sym
			case sym
				when :html_title
					@title = data
				when :html_message
					@message = data
				when :html_css
					@css = data
				else
					@cargo_table[sym] = data
			end
		rescue StandardError => e
			raise MirrorFileCorruptionError.new("Corrupted mirror file (segment '" + name + "') : " + e.class.to_s + " : " + e.to_s)
		end
		
		CARGO_BEGIN = "<!-- CARGO SEGMENT"
		CARGO_END = "END CARGO SEGMENT -->"
	end
end
