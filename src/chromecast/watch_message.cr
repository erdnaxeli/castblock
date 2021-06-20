require "json"

class Castblock::Chromecast
  struct WatchMessage
    include JSON::Serializable

    getter application : Application?
    getter media : Media?
    getter payload : String?
  end

  struct Application
    include JSON::Serializable

    @[JSON::Field(key: "displayName")]
    getter display_name : String
  end

  struct Media
    include JSON::Serializable

    struct Media
      include JSON::Serializable

      @[JSON::Field(key: "contentId")]
      getter content_id : String
      getter duration : Float64
    end

    @[JSON::Field(key: "playerState")]
    getter player_state : String
    @[JSON::Field(key: "currentTime")]
    getter current_time : Float64
    getter media : Media
  end
end
