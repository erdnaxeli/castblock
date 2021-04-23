class Castblock::Chromecast
  class Error < Exception
  end

  class HttpServerNotRunningError < Error
  end

  class CommandError < Error
  end
end
