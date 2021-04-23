require "log"

class Castblock::Blocker
  Log = Castblock::Log.for(self)

  @devices = Hash(String, Chromecast::Device).new

  def initialize(@chromecast : Chromecast, @sponsorblock : Sponsorblock)
  end

  def run : Nil
    watch_new_devices
  end

  private def watch_new_devices : Nil
    loop do
      Log.debug { "Checking for new devices" }
      new_devices.each do |device|
        spawn watch_device(device)
      end

      sleep 30.seconds
    end
  end

  private def new_devices : Array(Chromecast::Device)
    @chromecast.list_devices.select! do |device|
      if !@devices.has_key?(device.uuid)
        @devices[device.uuid] = device
        Log.info { "New device found: #{device.device_name} " }
        true
      end
    end
  rescue Chromecast::CommandError
    Log.warn { "Error while listing devices" }
    Array(Chromecast::Device).new
  end

  private def watch_device(device : Chromecast::Device) : Nil
    @chromecast.start_watcher(device) do |message|
      Log.debug &.emit("Received message", application: message.application.display_name)

      if message.application.display_name.downcase == "youtube" && (media = message.media)
        handle_media(device, media)
      end
    end
  end

  private def handle_media(device : Chromecast::Device, media : Chromecast::Media) : Nil
    Log.debug &.emit("Youtube video playing", id: media.media.content_id, current_time: media.current_time)

    segments = @sponsorblock.get_segments(media.media.content_id)
    if segments.nil?
      Log.debug &.emit("Unknown video", id: media.media.content_id)
      return
    end

    segments.each do |segment|
      if segment.segment[0] <= media.current_time < segment.segment[1] - 5
        Log.info &.emit(
          "Found a sponsor segment, skipping it.",
          id: media.media.content_id,
          start: segment.segment[0],
          end: segment.segment[1],
        )

        begin
          @chromecast.seek_to(device, segment.segment[1] - 1)
        rescue Chromecast::CommandError
          Log.error { "Error while seeking" }
        end
        break
      end
    end
  end
end
