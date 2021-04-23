require "http"
require "uri"

class Castblock::Sponsorblock
  Log = Castblock::Log.for(self)

  struct Segment
    include JSON::Serializable

    getter segment : Tuple(Float64, Float64)
  end

  @cache = Hash(String, Array(Segment)?).new

  def initialize
    @client = HTTP::Client.new("sponsor.ajay.app", tls: true)
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
      "category" => "sponsor",
      "videoID" => content_id,
    })
    response = get("/api/skipSegments?" + params)

    if response.status.success?
      Array(Segment).from_json(response.body)
    elsif response.status_code == 404
      nil
    else
      Log.warn &.emit("Error from Sponsorblock", status_code: response.status_code, video_id: content_id)
      nil
    end
  end

  private def save(content_id : String, segments : Array(Segment)?) : Nil
    @cache[content_id] = segments

    if @cache.size > 20
      @cache.shift
    end
  end

  private def get(path : String, retries=3) : HTTP::Client::Response
    response = @client.get(path)

    if !response.status.server_error?
      3.times do
        Log.debug &.emit("Received an error from Sponsorblock, retrying is 1s", status_code: response.status_code)
        sleep 1.second

        response = @client.get(path)
        break if !response.status.server_error?
      end
    end

    return response
  end
end
