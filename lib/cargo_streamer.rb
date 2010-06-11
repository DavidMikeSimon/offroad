require 'zlib'
require 'digest/md5'

require 'exceptions'

module OfflineMirror
  class CargoStreamerError < DataError
  end
  
  private
  
  # Class for encoding data to, and extracting data from, specially-formatted HTML comments which are called "cargo sections".
  # Each such section has a name, an md5sum for verification, and some base64-encoded zlib-compressed json data.
  # Multiple cargo sections can have the same name; when the cargo is later read, requests for that name will be yielded each section in turn.
  class CargoStreamer
    # Creates a new CargoStreamer on the given stream, which will be used in the given mode (must be "w" or "r").
    # If the mode is "r", the file is immediately scanned to determine what cargo it contains.
    def initialize(ioh, mode)
      raise CargoStreamerError.new("Invalid mode: must be 'w' or 'r'") unless ["w", "r"].include?(mode)
      @ioh = ioh
      @mode = mode
      scan_for_cargo if @mode == "r"
    end
    
    # Writes a cargo section with the given name and value to the IO stream.
    # Options:
    # * :human_readable => true - Before writing the cargo section, writes a human-readable comment with the value.
    #   The value must be Hash-like for this.
    def write_cargo_section(name, value, options = {})
      raise CargoStreamerError.new("Mode must be 'w' to write cargo data") unless @mode == "w"
      raise CargoStreamerError.new("CargoStreamer section names must be strings") unless name.is_a? String
      raise CargoStreamerError.new("Invalid cargo name '" + name + "'") unless name == clean_for_html_comment(name)
      raise CargoStreamerError.new("Unacceptable value type") unless encodable? value 
      
      begin
        if options[:human_readable]
          raise CargoStreamerError.new("Human readable data must be a hash") unless value.is_a? Hash
          @ioh.write "<!--\n"
          value.map{ |k,v| [k.to_s, v] }.sort.each do |k, v|
            @ioh.write clean_for_html_comment(k.titleize) + ": " + clean_for_html_comment(v.to_s) + "\n"
          end
          @ioh.write "-->\n"
        end
      rescue StandardError => e
        raise CargoStreamerError.new("Unable to make human-readable comment : #{e.class.to_s} : #{e.to_s}")
      end
      
      name = name.chomp
      deflated_data = Zlib::Deflate::deflate(value.to_xml)
      b64_data = Base64.encode64(deflated_data).chomp
      digest = Digest::MD5::hexdigest(deflated_data).chomp
      
      @ioh.write CARGO_BEGIN + "\n"
      @ioh.write name + "\n"
      @ioh.write digest + "\n"
      @ioh.write b64_data + "\n"
      @ioh.write CARGO_END + "\n"
    end
    
    # Returns a list of cargo section names available to be read
    def cargo_section_names
      return @cargo_locations.keys
    end
    
    # Returns true if cargo with a given name is available
    def has_cargo_named?(name)
      return @cargo_locations.has_key? name
    end
    
    # Reads, verifies, decodes, and returns the first cargo section with a given name
    def first_cargo_section(name)
      each_cargo_section(name) do |data|
        return data
      end
    end
    
    # Reads, verifies, and decodes each cargo section with a given name, passing each section's decoded data to the block
    def each_cargo_section(name)
      raise CargoStreamerError.new("Mode must be 'r' to read cargo data") unless @mode == "r"
      locations = @cargo_locations[name] or return nil
      locations.each do |seek_location|
        @ioh.seek(seek_location)
        digest = ""
        encoded_data = ""
        @ioh.each_line do |line|
          line.chomp!
          if line == CARGO_END
            break
          elsif digest == ""
            digest = line
          else
            encoded_data += line
          end
        end
        
        yield verify_and_decode_cargo(digest, encoded_data)
      end
    end
    
    private
    
    def encodable?(value, depth = 0)
      return false unless value.respond_to?(:to_xml)
      return false if depth > 4 # Protect against excessively deep structures
      
      # Attempt to descend into the object to make sure all its children are also xmlifiable
      if value.respond_to?(:each)
        value.each do |val|
          return false unless encodable?(val, depth + 1)
        end
      elsif value.respond_to(:each_pair)
        value.each do |key, val|
          return false unless key.class == String # XML only supports string keys, since they'll become tags
          return false unless encodable?(val, depth + 1)
        end
      elsif value.respond_to(:attributes) # For ActiveRecord instances
        return false unless encodable?(val.attributes, depth + 1)
      end
      
      return true
    end
    
    def scan_for_cargo
      # Key is cargo section name as String, value is array of seek locations to digests for that section
      @cargo_locations = {}
      @ioh.rewind
      
      in_cargo = false
      found_name = false
      @ioh.each_line do |line|
        line.chomp!
        if in_cargo
          if line.include? CARGO_END
            in_cargo = false
            found_name = false
          else
            unless found_name
              @cargo_locations[line] ||= []
              @cargo_locations[line] << @ioh.tell
              found_name = true
            end
          end
        else
          if line.include? CARGO_BEGIN
            in_cargo = true
          end
        end
      end
      raise CargoStreamerError.new("Input contained un-terminated cargo section") unless in_cargo == false
      
      @ioh.rewind
    end
    
    def clean_for_html_comment(s)
      s.to_s.gsub("--", "__").gsub("<", "[").gsub(">", "]").gsub("\n", "")
    end
    
    def verify_and_decode_cargo(digest, b64_data)
      deflated_data = Base64.decode64(b64_data)
      raise "MD5 check failure" unless Digest::MD5::hexdigest(deflated_data) == digest
      return JSON::parse(Zlib::Inflate::inflate(deflated_data))
    rescue StandardError => e
      raise CargoStreamerError.new("Corrupted data : #{e.class.to_s} : #{e.to_s}")
    end
    
    CARGO_BEGIN = "<!-- CARGO SEGMENT"
    CARGO_END = "END CARGO SEGMENT -->"
  end
end
