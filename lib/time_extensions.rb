module OfflineMirror
  module TimeExtensions
    def xmlschema_with_default_subseconds(precision = 12)
      xmlschema_without_default_subseconds(precision)
    end
  end
end

[Time, ActiveSupport::TimeWithZone].each do |cls|
  cls.send(:include, OfflineMirror::TimeExtensions)
  cls.alias_method_chain :xmlschema, :default_subseconds
end