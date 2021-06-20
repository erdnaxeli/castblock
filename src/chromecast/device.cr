require "json"

class Castblock::Chromecast
  struct Device
    include JSON::Serializable

    @[JSON::Field(key: "device_name")]
    getter name : String
    getter uuid : String

    def_equals_and_hash @uuid
  end
end
