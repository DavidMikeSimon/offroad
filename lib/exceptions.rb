module OfflineMirror
  class DataError < RuntimeError
  end
  
  class ModelError < RuntimeError
  end
  
  class PluginError < RuntimeError
  end
  
  class AppModeUnknownError < RuntimeError
  end
end