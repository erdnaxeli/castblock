require "log"
require "http"
require "process"
require "uri"

require "./chromecast/*"

class Castblock::Chromecast
  Log = Castblock::Log.for(self)

  @bin : String
  @client : HTTP::Client? = nil
  @server_running = false
  @video_ids = Channel(String).new

  def initialize
    @bin = find_executable
    spawn start_server
    while !@server_running
      sleep 0.5
    end
  end

  def list_devices : Array(Device)
    response = client.get("/devices")
    if !response.status.success?
      Log.debug &.emit("Error while getting devices", status_code: response.status_code, error: response.body)
      raise CommandError.new
    end

    Array(Device).from_json(response.body)
  end

  def seek_to(device : Device, timestamp : Float64) : Nil
    params = HTTP::Params.encode({
      "uuid"    => device.uuid,
      "seconds" => timestamp.to_s,
    })
    response = client.post("/seek-to?" + params)

    if !response.status.success?
      Log.error &.emit("Error with seek_to", status_code: response.status_code, error: response.body)
      raise CommandError.new
    end
  end

  def set_mute(device : Device, value : Bool) : Nil
    params = HTTP::Params.encode({
      "uuid"    => device.uuid,
    })
    response = client.post("/#{value ? "" : "un"}mute?" + params)

    if !response.status.success?
      Log.error &.emit("Error with mute", status_code: response.status_code, error: response.body)
      raise CommandError.new
    end
  end

  def start_watcher(device : Device, continue : Channel(Nil), &block : WatchMessage ->) : Nil
    loop do
      Log.info &.emit("Connect to device", uuid: device.uuid)
      begin
        connect(device)
      rescue CommandError
        continue.close
        return
      end

      Log.info &.emit("Starting go-chromecast watcher", uuid: device.uuid)
      Process.run(@bin, args: ["watch", "--output", "json", "--interval", "2", "-u", device.uuid]) do |process|
        while output = process.output.gets
          begin
            message = WatchMessage.from_json(output)
          rescue ex
            Log.debug { "Invalid message: #{ex}" }
          else
            yield message
          end

          if continue.closed?
            process.terminate
            return
          end
        end
      end

      return if continue.closed?

      Log.warn &.emit("go-chromecast has quit.", uuid: device.uuid)
      Log.warn &.emit("Restarting go-chromecast watcher in 5s.", uuid: device.uuid)
      sleep 5.seconds
    end
  end

  private def connect(device : Device) : Nil
    params = HTTP::Params.encode({
      "uuid" => device.uuid,
    })
    response = client.post("/connect?" + params)

    if !response.status.success? && response.body.chomp != "device uuid is already connected"
      Log.error &.emit(
        "Error while connecting to device",
        uuid: device.uuid,
        status_code: response.status_code,
        error: response.body.chomp,
      )
      raise CommandError.new
    end
  end

  private def client : HTTP::Client
    if !@server_running
      raise HttpServerNotRunningError.new
    end

    if client = @client
      client
    else
      @client = HTTP::Client.new("127.0.0.1", port: 8011)
    end
  end

  private def find_executable : String
    bin = Process.find_executable("go-chromecast")
    if bin.nil?
      Log.fatal { "No go-chromecast executable found in the PATH." }
      raise "missing go-chromecast executable"
    end

    Log.info { "Found go-chromecast at #{bin}." }
    bin
  end

  private def start_server : Nil
    loop do
      Log.info { "Starting the go-chromecast server." }
      Process.run(@bin, args: ["httpserver", "-p", "8011"]) do |process|
        @server_running = true
        error = process.error.gets_to_end
        @server_running = false

        Log.warn { "The go-chromecast server has quit." }
        Log.warn { error }
      end

      Log.warn { "Restart go-chromecast server in 5s." }
      sleep 5.seconds
    end
  end
end
