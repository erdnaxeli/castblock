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
    @[Clip::Doc("The category of segments to block. It can be repeated to block multiple categories.")]
    @categories = ["sponsor"]
    @[Clip::Option("--mute-ads")]
    @[Clip::Doc("Enable auto muting adsense ads on youtube.")]
    @mute_ads : Bool = false
    @[Clip::Option("--skip-ads")]
    @[Clip::Doc("Enable auto skipping adsense ads on youtube.")]
    @skip_ads : Bool = false
    @[Clip::Option("--merge-threshold")]
    @[Clip::Doc("The maximum number of seconds between segments to be merged. "\
                "Adjust this value to skip multiple adjacent segments that don't overlap.")]
    @merge_threshold = 0.0

    def read_env
      # If a config option equals its default value, we try to read it from the env.
      # This is a temporary hack while waiting for Clip to handle it in a better way.
      @debug = read_env_bool(@debug, nil, "DEBUG")
      @seek_to_offset = read_env_int(@seek_to_offset, 0, "OFFSET")
      @categories = read_env_str_array(@categories, ["sponsor"], "CATEGORIES")
      @mute_ads = read_env_bool(@mute_ads, false, "MUTE_ADS")
      @merge_threshold = read_env_float(@merge_threshold, 0.0, "MERGE_THRESHOLD")
    end

    def read_env_bool(value : Bool?, default : Bool?, name : String) : Bool?
      if value == default && (var = ENV[name]?)
        var.downcase == "true"
      else
        value
      end
    end

    def read_env_str_array(value : Array(String), default : Array(String), name : String) : Array(String)
      if value == default && (var = ENV[name]?)
        var.split(',')
      else
        value
      end
    end

    def read_env_int(value : Int, default : Int, name : String) : Int
      if value == default && (var = ENV[name]?)
        var.to_i
      else
        value
      end
    end

    def read_env_float(value : Float, default : Float, name : String) : Float
      if value == default && (var = ENV[name]?)
        var.to_f
      else
        value
      end
    end

    def run : Nil
      read_env

      if @debug
        ::Log.setup(:debug)
      end

      begin
        sponsorblock = Sponsorblock.new(@categories.to_set)
      rescue Sponsorblock::CategoryError
        return
      end

      chromecast = Chromecast.new
      blocker = Blocker.new(chromecast, sponsorblock, @seek_to_offset, @mute_ads, @skip_ads, @merge_threshold)

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
