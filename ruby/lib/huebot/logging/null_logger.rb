module Huebot
  module Logging
    class NullLogger
      def log(_event_type, _data = {})
        self
      end
    end
  end
end
