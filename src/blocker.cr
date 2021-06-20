require "log"
require "json"

class Castblock::Blocker
  Log = Castblock::Log.for(self)

  @devices = Hash(Chromecast::Device, Channel(Nil)).new

  def initialize(@chromecast : Chromecast, @sponsorblock : Sponsorblock, @mute_ads : Bool)
  end

  def run : Nil
    watch_new_devices
  end

  private def watch_new_devices : Nil
    loop do
      Log.debug { "Checking for new devices" }
      @devices.reject! { |_, continue| continue.closed? }

      begin
        devices = @chromecast.list_devices.to_set
      rescue Chromecast::CommandError
        Log.warn { "Error while listing devices" }
      else
        new_devices = devices - @devices.keys
        new_devices.each do |device|
          Log.info &.emit("New device found", name: device.device_name, uuid: device.uuid)
          @devices[device] = Channel(Nil).new
          spawn watch_device(device, @devices[device])
        end

        @devices.each_key do |device|
          if !devices.includes?(device) && (continue = @devices.delete(device))
            Log.info &.emit("A device is gone", name: device.device_name, uuid: device.uuid)
            continue.close
          end
        end
      end

      sleep 30.seconds
    end
  end

  private def watch_device(device : Chromecast::Device, continue : Channel(Nil)) : Nil
    @chromecast.start_watcher(device, continue) do |message|
      if application = message.application
        Log.debug &.emit("Received message", application: application.display_name)
        if application.display_name.downcase == "youtube" && (media = message.media)
          handle_media(device, media)
        end
      end

      if @mute_ads && (payload = message.payload)
        data = JSON.parse(payload)
        if data["status"]? && (player_state = data["status"][0]["customData"]["playerState"].as_i)
          handle_monetization(device, player_state)
        end
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
        end
        break
      end
    end
  end

  private def handle_monetization(device : Chromecast::Device, player_state : Int) : Nil
    if player_state == 1081
      Log.info &.emit("Found ad, muting audio", device: device.device_name)
      @chromecast.set_mute(device, true)
    else
      Log.info &.emit("Ad ended, unmuting audio", device: device.device_name)
      @chromecast.set_mute(device, false)
    end
  end
end
