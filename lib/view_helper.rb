module Offroad
  module ViewHelper
    def link_to_online_app(name = nil)
      link_to(name ? name : Offroad::online_url, Offroad::online_url)
    end
  end
end
