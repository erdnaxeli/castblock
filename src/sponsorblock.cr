require "http"
require "uri"

class Castblock::Sponsorblock
  class Error < Exception
  end

  class CategoryError < Error
  end

  Log = Castblock::Log.for(self)

  struct Segment
    include JSON::Serializable

    getter category : String
    getter segment : Tuple(Float64, Float64)
  end

  @cache = Hash(String, Array(Segment)?).new

  def initialize(@categories : Set(String))
    @client = HTTP::Client.new("sponsor.ajay.app", tls: true)

    if !@categories.subset_of?(Set{"sponsor", "intro", "outro", "selfpromo", "interaction", "music_offtopic", "preview"})
      Log.fatal { "Invalid categories #{@categories.join(", ")}. Available categories are sponsor, intro, outro, selfpromo, interaction, music_offtopic or preview." }
      raise CategoryError.new
    end
  end

  def get_segments(content_id : String) : Array(Segment)?
    if @cache.has_key?(content_id)
      @cache[content_id]
    else
      segments = get_segments_internal(content_id)
      save(content_id, segments)
      segments
    end
  end

  private def get_segments_internal(content_id : String) : Array(Segment)?
    params = URI::Params.encode({
      "categories" => @categories.to_json,
      "videoID"    => content_id,
    })
    response = get("/api/skipSegments?" + params)

    if response.status.success?
      Array(Segment).from_json(response.body)
    elsif response.status_code == 404
      nil
    else
      Log.error &.emit("Error from Sponsorblock", status_code: response.status_code, video_id: content_id)
      nil
    end
  end

  private def save(content_id : String, segments : Array(Segment)?) : Nil
    @cache[content_id] = segments

    if @cache.size > 20
      @cache.shift
    end
  end

  private def get(path : String, retries = 3) : HTTP::Client::Response
    begin
      response = @client.get(path)
    rescue ex : Socket::Addrinfo::Error
      Log.warn &.emit("DNS error", error: ex.to_s)
      raise Error.new(cause: ex)
    end

    if response.status.server_error?
      3.times do
        Log.warn &.emit("Received an error from Sponsorblock, retrying in 1s", status_code: response.status_code)
        sleep 1.second

        response = @client.get(path)
        break if !response.status.server_error?
      end
    end

    response
  end
end
