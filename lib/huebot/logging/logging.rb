module Huebot
  module Logging
    autoload :NullLogger, 'huebot/logging/null_logger'
    autoload :CollectingLogger, 'huebot/logging/collecting_logger'
    autoload :IOLogger, 'huebot/logging/io_logger'
  end
end
