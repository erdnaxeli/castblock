require "clip"

require "./blocker"
require "./chromecast"
require "./sponsorblock"

module Castblock
  VERSION = "0.1.0"

  Log = ::Log.for(self)

  struct Command
    include Clip::Mapper

    @debug : Bool? = nil
    @[Clip::Option("--offset")]
    @[Clip::Doc("When skipping a sponsor segment, jump to this number of seconds before " \
                "the end of the segment.")]
    @seek_to_offset = 0
    @[Clip::Option("--category")]
    @[Clip::Doc("The category to block. It can be repeated to block multiple categories.")]
    @categories = ["sponsor"]
    @[Clip::Option("--mute-ads")]
    @[Clip::Doc("Enable auto muting adsense ads on youtube.")]
    @mute_ads : Bool = false

    def run : Nil
      if @debug
        ::Log.setup(:debug)
      end

      begin
        sponsorblock = Sponsorblock.new(@categories.to_set)
      rescue Sponsorblock::CategoryError
        return
      end

      chromecast = Chromecast.new
      blocker = Blocker.new(chromecast, sponsorblock, @seek_to_offset, @mute_ads)

      blocker.run
    end
  end

  def self.run
    begin
      command = Command.parse
    rescue ex : Clip::Error
      puts ex
      return
    end

    case command
    when Clip::Mapper::Help
      puts command.help
    else
      command.run
    end
  end
end

Castblock.run
