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
  # The data must always be in the form of arrays of ActiveRecord, or things that walk sufficiently like ActiveRecord
  class CargoStreamer
    # Models which are to be encoded need to have a method safe_to_load_from_cargo_stream? that returns true.
    
    # Creates a new CargoStreamer on the given stream, which will be used in the given mode (must be "w" or "r").
    # If the mode is "r", the file is immediately scanned to determine what cargo it contains.
    def initialize(ioh, mode)
      raise CargoStreamerError.new("Invalid mode: must be 'w' or 'r'") unless ["w", "r"].include?(mode)
      @mode = mode
      
      if ioh.is_a? String
        raise CargoStreamerError.new("Cannot accept string as ioh in write mode") unless @mode == "r"
        @ioh = StringIO.new(ioh, "r")
      else
        @ioh = ioh
      end
      
      scan_for_cargo if @mode == "r"
    end
    
    # Writes a cargo section with the given name and value to the IO stream.
    # Options:
    # * :human_readable => true - Before writing the cargo section, writes a comment with human-readable data.
    # * :include => [:assoc, :other_assoc] - Includes these first-level associations in the encoded data
    def write_cargo_section(name, value, options = {})
      raise CargoStreamerError.new("Mode must be 'w' to write cargo data") unless @mode == "w"
      raise CargoStreamerError.new("CargoStreamer section names must be strings") unless name.is_a? String
      raise CargoStreamerError.new("Invalid cargo name '" + name + "'") unless name == clean_for_html_comment(name)
      raise CargoStreamerError.new("Cargo name cannot include newlines") if name.include?("\n")
      raise CargoStreamerError.new("Value must be an array") unless value.is_a? Array
      [:to_xml, :attributes=, :valid?].each do |message|
        unless value.all? { |e| e.respond_to? message }
          raise CargoStreamerError.new("All elements must respond to #{message}") 
        end
      end
      unless value.all? { |e| e.class.respond_to?(:safe_to_load_from_cargo_stream?) && e.class.safe_to_load_from_cargo_stream? }
        raise CargoStreamerError.new("All element classes must be models which are safe_to_load_from_cargo_stream")
      end
      
      unless options[:skip_validation]
        unless value.all? { |e| e.valid? }
          raise CargoStreamerError.new("All elements must be valid")
        end
      end
      
      if options[:human_readable]
        human_data = value.map{ |rec|
          rec.attributes.map{ |k, v| "#{k.to_s.titleize}: #{v.to_s}" }.join("\n")
        }.join("\n\n")
        @ioh.write "<!--\n"
        @ioh.write name.titleize + "\n"
        @ioh.write "\n"
        @ioh.write clean_for_html_comment(human_data) + "\n"
        @ioh.write "-->\n"
      end
      
      name = name.chomp
      
      assoc_list = options[:include] || []
      
      xml = Builder::XmlMarkup.new
      xml_data = "<records>%s</records>" % value.map {
        |r| r.to_xml(
          :skip_instruct => true,
          :skip_types => true,
          :root => "record",
          :indent => 0,
          :include => assoc_list
        ) do |xml|
          xml.cargo_streamer_type r.class.name
          assoc_info = assoc_list.reject{|a| r.send(a) == nil}.map{|a| "#{a.to_s}=#{r.send(a).class.name}"}.join(",")
          xml.cargo_streamer_includes assoc_info
        end
      }.join()
      deflated_data = Zlib::Deflate::deflate(xml_data)
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
    
    # Returns the first element from the return value of first_cargo_section
    def first_cargo_element(name)
      arr = first_cargo_section(name)
      return (arr && arr.size > 0) ? arr[0] : nil
    end
    
    # Reads, verifies, and decodes each cargo section with a given name, passing each section's decoded data to the block
    def each_cargo_section(name)
      raise CargoStreamerError.new("Mode must be 'r' to read cargo data") unless @mode == "r"
      locations = @cargo_locations[name] or return
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
      s.to_s.gsub("--", "__").gsub("<", "[").gsub(">", "]")
    end
    
    def compose_record_from_hash(model_class_name, attrs_hash)
      model_class = model_class_name.constantize
      raise "Class #{model_class_name} does not have cargo safety method" unless model_class.respond_to? :safe_to_load_from_cargo_stream?
      raise "Class #{model_class_name} is not safe_to_load_from_cargo_stream" unless model_class.safe_to_load_from_cargo_stream?
      
      rec = model_class.new
      rec.send(:attributes=, attrs_hash, false) # No attr_accessible check like this, so all attributes can be set
      rec.readonly! # rec is just source data for creation of a "real" record; it shouldn't be saveable itself
      rec
    end
    
    def verify_and_decode_cargo(digest, b64_data)
      deflated_data = Base64.decode64(b64_data)
      raise "MD5 check failure" unless Digest::MD5::hexdigest(deflated_data) == digest
      
      # Even though we encoded an Array with Array#to_xml, there is no Array#from_xml
      # So, we have to use Hash#from_xml
      records = Hash.from_xml(Zlib::Inflate::inflate(deflated_data))["records"]["record"]
      raise "Decode failure, unable to find records key" unless records != nil
      records = [records] unless records.is_a?(Array)
      return records.map do |attrs_hash|
        raise "Unable to find record type" unless attrs_hash.has_key?("cargo_streamer_type")
        class_name = attrs_hash.delete("cargo_streamer_type")
        
        raise "Unable to find includes list" unless attrs_hash.has_key?("cargo_streamer_includes")
        (attrs_hash.delete("cargo_streamer_includes") || "").split(",").each do |assoc_info|
          assoc_name, i_class_name = assoc_info.split("=")
          attrs_hash[assoc_name] = compose_record_from_hash(i_class_name, attrs_hash[assoc_name])
        end
        
        compose_record_from_hash(class_name, attrs_hash)
      end
    rescue StandardError => e
      raise CargoStreamerError.new("Corrupted data : #{e.class.to_s} : #{e.to_s}")
    end
    
    CARGO_BEGIN = "<!-- CARGO SEGMENT"
    CARGO_END = "END CARGO SEGMENT -->"
  end
end
