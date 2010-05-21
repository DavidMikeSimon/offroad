require 'zlib'
require 'digest/md5'

module OfflineMirror
	class CargoFileCorruptionError < RuntimeError
		def initialize(msg)
			super(msg)
		end
	end
	
	private
	
	class CargoFile
		# Hash with symbols as keys, values either json-ifiable data or an object with a call method that returns json-ifiable data
		attr_accessor :cargo_table
		
		# Creates a new CargoFile; if an argument is given, it is treated as an input stream from which encoded cargo data is read
		def initialize(ioh = nil)
			@cargo_table = { :file_info => {} }
			if ioh
				read_from(ioh)
			end
		end
		
		# Writes HTML comments containing the cargo data to the given IO stream
		def write_to(ioh)
			ioh.write "<!-- This file contains encapsulated data.\n"
			@cargo_table[:file_info].keys.map{ |k| [k.to_s, @cargo_table[:file_info][k]] }.sort.each do |k, v|
				ioh.write clean_for_html_comment(k.titleize) + ": " + clean_for_html_comment(v) + "\n"
			end
			ioh.write "-->\n"
			
			cargo_table.each_pair do |k, v|
				name = k.to_s
				orig_data = v.respond_to?(:call) ? v.call : v
				deflated_data = Zlib::Deflate::deflate(v.to_json)
				b64_data = Base64.encode64(deflated_data).chomp
				digest = Digest::MD5::hexdigest(deflated_data).chomp
				
				raise "Invalid cargo name '" + name + "'" unless name == clean_for_html_comment(name)
				
				ioh.write CARGO_BEGIN + "\n"
				ioh.write name + "\n"
				ioh.write digest + "\n"
				ioh.write b64_data + "\n"
				ioh.write CARGO_END + "\n"
			end
		end

		# Calls the write_to method and returns a string with the output
		def write_to_string
			sio = StringIO.new
			write_to(sio)
			sio.close
			return sio.string
		end
		
		private
		
		def clean_for_html_comment(s)
			s.to_s.gsub("--", "__").gsub("<", "[").gsub(">", "]").gsub("\n", "")
		end
		
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
			
			raise CargoFileCorruptionError.new("Input contained un-terminated cargo section") unless in_cargo == false
		end
		
		def import_cargo(name, digest, b64_data)
			deflated_data = Base64.decode64(b64_data)
			raise "MD5 check failure" unless Digest::MD5::hexdigest(deflated_data) == digest
			data = ActiveSupport::JSON.decode(Zlib::Inflate::inflate(deflated_data))
			@cargo_table[name.to_sym] = data
		rescue StandardError => e
			raise CargoFileCorruptionError.new("Corrupted mirror file (segment '" + name + "') : " + e.class.to_s + " : " + e.to_s)
		end
		
		CARGO_BEGIN = "<!-- CARGO SEGMENT"
		CARGO_END = "END CARGO SEGMENT -->"
	end
end
