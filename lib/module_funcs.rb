module OfflineMirror
  VERSION_MAJOR = 0
  VERSION_MINOR = 1
  
  @@app_online_flag = nil
  
  # Used in the environment configuration file to set the app to online or offline mode.
  # This should not be called from within the app.
  def self.config_app_online(flag)
    @@app_online_flag = flag
  end
  
  # Returns true if the app is in offline mode (running on a local system without access to the main server)
  def self.app_offline?
    not app_online?
  end
  
  # Returns true if the app is in online mode (or in other words, this is the main server)
  def self.app_online?
    case @@app_online_flag
      when true then true
      when false then false
      else raise AppModeUnknownError.new
    end
  end
  
  # Returns a Time that identifies the version of the app
  # Specifically, the modification timestamp (on the online app) of the most recently modified source file in the app
  def self.app_version
    # TODO Implement
    # Online - When app is launched, scan all application files, returns the Time of the most recently changed file
    # Offline - Based on the app version noted in the last down-mirror file successfully loaded
    return 1
  end
  
  #:nodoc#
  def self.init
    @@config = YAML.load_file(File.join(RAILS_ROOT, "config", "offline_mirror.yml"))
  end
  
  # Returns the record of the group base model that this app is in charge of
  # This is only applicable if the app is offline
  def self.offline_group
    raise PluginError.new("'Offline group' is only meaningful if the app is offline") unless app_offline?
    @@group_base_model.find(OfflineMirror::SystemState::offline_group_id)
  end
  
  private
  
  def self.online_url
    @@config[:online_url] or raise PluginError.new("No online url specified in offline mirror config")
  end
  
  def self.app_name
    @@config[:app_name] or raise PluginError.new("No app name specified in offline mirror config")
  end
  
  def self.note_global_data_model(cls)
    @@global_data_models ||= {}
    @@global_data_models[cls.name] = cls
  end
  
  def self.global_data_models
    @@global_data_models || {}
  end
  
  def self.note_group_base_model(cls)
    if defined?(@@group_base_model) and @@group_base_model.to_s != cls.to_s
      raise ModelError.new("You can only define one group base model")
    end
    @@group_base_model = cls
  end
  
  def self.group_base_model
    raise ModelError.new("No group base model was specified") unless defined?(@@group_base_model)
    @@group_base_model
  end
  
  def self.note_group_owned_model(cls)
    @@group_owned_models ||= {}
    @@group_owned_models[cls.name] = cls
  end
  
  def self.group_owned_models
    @@group_owned_models || {}
  end
end
