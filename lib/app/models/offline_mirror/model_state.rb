module OfflineMirror
  private
  
  class ModelState < ActiveRecord::Base
    set_table_name "offline_mirror_model_states"
    
    validates_presence_of :app_model_name
    
    def validate
      model = nil
      begin
        model = app_model
      rescue NameError
        errors.add_to_base "Given model name does not correspond to a constant"
      end
      
      if model
        errors.add_to_base "Constant is not a mirrored model" unless self.class.valid_model?(model)
      end
    end
    
    named_scope :for_model, lambda { |model| { :conditions => {
      :app_model_name => valid_model?(model) ? model.name : nil
    } } }
    
    def app_model
      app_model_name.constantize
    end
    
    private
    
    def self.valid_model?(model)
      model.respond_to?(:acts_as_mirrored_offline?) && model.acts_as_mirrored_offline?
    end
  end
end
