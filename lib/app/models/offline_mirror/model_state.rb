module OfflineMirror
  private
  
  class ModelState < ActiveRecord::Base
    set_table_name "offline_mirror_model_states"
    
    validates_presence_of :app_model_name
    
    def self.find_or_create_by_model(cls, opts = {})
      ensure_mirrored_model(cls)
      find_or_create_by_app_model_name(cls.to_s, opts)
    end

    def app_model
      app_model_name.constantize
    end
    
    private
    
    def self.ensure_mirrored_model(cls)
      unless cls.acts_as_mirrored_offline?
        raise ModelError.new("Passed class doesn't specify acts_as_mirrored_offline")
      end
    end
  end
end
