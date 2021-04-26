require "json"

class Castblock::Chromecast
  struct Device
    include JSON::Serializable

    getter device_name : String
    getter uuid : String

    def_equals_and_hash @uuid
  end
end
