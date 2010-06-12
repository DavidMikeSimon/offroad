module OfflineMirror
  class GroupBaseController < ApplicationController
    protected
    
    def render_up_mirror_file(group, filename, render_args = {})
      raise PluginError.new("Cannot generate up-mirror file when app in online mode") if OfflineMirror::app_online?
      render_appending_cargo_data(group, filename, render_args) do |cargo_streamer|
        write_group_specific_cargo(group, cargo_streamer)
      end
    end
    
    def render_down_mirror_file(group, filename, render_args = {})
      raise PluginError.new("Cannot generate down-mirror file when app in offline mode") if OfflineMirror::app_offline?
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
        write_model_cargo(cargo_streamer, cls, :conditions => { cls.offline_mirror_group_key.to_sym => group })
      end
      
      write_model_cargo(cargo_streamer, OfflineMirror::group_base_model, :conditions => { :id => group.id })
    end
    
    def write_global_cargo(group, cargo_streamer)
      # FIXME: Indicate what down-mirror version this is
      # FIXME: Also allow for a full-sync mode (includes all records)
      OfflineMirror::global_data_models.each do |name, cls|
        write_model_cargo(cargo_streamer, cls)
      end
    end
    
    def write_model_cargo(cargo_streamer, model, find_options = {})
      # FIXME: Also include id transformation by joining with the mirrored_records table
      # FIXME: Include entries for deleted records
      # FIXME: Check against mirror version
      model.find_in_batches(find_options.merge({:batch_size => 100})) do |batch|
        cargo_streamer.write_cargo_section("data_#{model.name}", batch)
      end
    end
    
    def render_appending_cargo_data(group, filename, render_args)
      # Encourage browser to download this to disk instead of displaying it
      headers['Content-Disposition'] = "attachment; filename=\"#{filename}\""
      orig_html = render_to_string render_args
      
      render_proc = Proc.new do |response, output|
        output.write(orig_html)
        cargo_streamer = CargoStreamer.new(output, "w")
        # FIXME: Is there some way to make sure this entire process occurs in a kind of read transaction?
        # These lines append standard information that should be included in every mirror file
        file_info = {
          "created_at" => Time.now.to_s,
          "online_site" => OfflineMirror::online_url,
          "app" => OfflineMirror::app_name,
          "app_mode" => OfflineMirror::app_online? ? "Online" : ("Offline for Group " + OfflineMirror::offline_group_id),
          "app_version" => OfflineMirror::app_version,
          "operating_system" => RUBY_PLATFORM,
          "for_group" => group.id,
          "plugin" => "Offline Mirror " + OfflineMirror::VERSION_MAJOR.to_s + "." + OfflineMirror::VERSION_MINOR.to_s
        }
        #cargo_streamer.write_cargo_section("file_info", file_info, :human_readable => true)
        #cargo_streamer.write_cargo_section("group_state", group.group_state.attributes)
        #schema_migrations = OfflineMirror::group_base_model.connection.select_all("SELECT * FROM schema_migrations")
        #cargo_streamer.write_cargo_section("schema_migrations", schema_migrations)
        
        yield cargo_streamer # Yields to the block provided to render_appending_cargo_data
      end
      
      render :text => render_proc
    end
  end
end
