module OfflineMirror
  class GroupBaseController < ApplicationController
    protected
    
    def render_up_mirror_file(group, filename, render_args = {})
      ensure_group_offline(group)
      raise PluginError.new("Cannot generate up-mirror file when app in online mode") if OfflineMirror::app_online?
      render_appending_mirror_data(group, filename, render_args) do |mirror_data|        
        mirror_data.write_upwards_data
      end
    end
    
    def render_down_mirror_file(group, filename, initial_file, render_args = {})
      ensure_group_offline(group)
      raise PluginError.new("Cannot generate down-mirror file when app in offline mode") if OfflineMirror::app_offline?
      render_appending_mirror_data(group, filename, render_args) do |mirror_data|
        if initial_file
          mirror_data.write_initial_downwards_data
        else
          mirror_data.write_downwards_data
        end
      end
    end
    
    def load_up_mirror_file(group, data)
      ensure_group_offline(group)
      raise PluginError.new("Cannot accept up mirror file when app is in offline mode") if OfflineMirror::app_offline?
      MirrorData.new(group, [data, "r"]).load_upwards_data
    end
    
    def load_down_mirror_file(group, data)
      ensure_group_offline(group) if group
      raise PluginError.new("Cannot accept down mirror file when app is in online mode") if OfflineMirror::app_online?
      MirrorData.new(group, [data, "r"]).load_downwards_data
    end
    
    private
    
    def ensure_group_offline(group)
      raise PluginError.new("Cannot perform mirror operations on online group") unless group.group_offline?
    end
    
    def render_appending_mirror_data(group, filename, render_args)
      # Encourage browser to download this to disk instead of displaying it
      headers['Content-Disposition'] = "attachment; filename=\"#{filename}\""
      viewable_content = render_to_string render_args
      
      render_proc = Proc.new do |response, output|
        output.write(viewable_content)
        mirror_data = MirrorData.new(group, CargoStreamer.new(output, "w"))
        yield mirror_data
      end
      
      render :text => render_proc
    end
  end
end