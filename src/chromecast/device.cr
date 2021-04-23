require "json"

class Castblock::Chromecast
  struct Device
    include JSON::Serializable

    getter device_name : String
    getter uuid : String
  end
end
