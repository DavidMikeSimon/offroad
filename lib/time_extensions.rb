class Time
  def xmlschema_with_default_subseconds
    xmlschema_without_default_subseconds(12)
  end
  alias_method_chain :xmlschema, :default_subseconds
end
