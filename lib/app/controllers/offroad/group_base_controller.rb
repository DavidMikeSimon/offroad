module Offroad
  class GroupBaseController < ApplicationController
    protected
    
    def render_up_mirror_file(group, filename, render_args = {})
      ensure_group_offline(group)
      raise PluginError.new("Cannot generate up-mirror file when app in online mode") if Offroad::app_online?
      mirror_data = MirrorData.new(group)
      render_appending_mirror_data(group, filename, render_args) do |output|
        mirror_data.write_upwards_data(output)
      end
    end
    
    def render_down_mirror_file(group, filename, render_args = {})
      ensure_group_offline(group)
      raise PluginError.new("Cannot generate down-mirror file when app in offline mode") if Offroad::app_offline?
      mirror_data = MirrorData.new(group, :initial_mode => render_args.delete(:initial_mode))
      render_appending_mirror_data(group, filename, render_args) do |output|
        mirror_data.write_downwards_data(output)
      end
    end
    
    def load_up_mirror_file(group, data)
      ensure_group_offline(group)
      raise PluginError.new("Cannot accept up mirror file when app is in offline mode") if Offroad::app_offline?
      MirrorData.new(group).load_upwards_data(data)
    end
    
    def load_down_mirror_file(group, data, options = {})
      ensure_group_offline(group) if group
      raise PluginError.new("Cannot accept down mirror file when app is in online mode") if Offroad::app_online?
      MirrorData.new(group, :initial_mode => options[:initial_mode]).load_downwards_data(data)
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
        yield output
      end
      
      render :text => render_proc
    end
  end
end
