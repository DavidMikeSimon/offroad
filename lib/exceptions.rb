module Offroad
  class DataError < RuntimeError
  end
  
  class OldDataError < DataError
  end
  
  class ModelError < RuntimeError
  end
  
  class PluginError < RuntimeError
  end
  
  class AppModeUnknownError < RuntimeError
  end
end
