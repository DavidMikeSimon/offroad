module OfflineMirror
  module ViewHelper
    def link_to_online_app(name = nil)
      link_to(name ? name : OfflineMirror::online_url, OfflineMirror::online_url)
    end
  end
end
