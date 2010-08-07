module OfflineMirror
  private
  
  class ModelState < ActiveRecord::Base
    set_table_name "offline_mirror_model_states"
    
    validates_presence_of :app_model_name
    
    def self.find_or_create_by_model(cls, opts = {})
      find_or_create_by_app_model_name(cls.to_s, opts)
    end

    def app_model
      app_model_name.constantize
    end
  end
end
