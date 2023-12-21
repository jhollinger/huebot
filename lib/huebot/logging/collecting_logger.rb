module Huebot
  module Logging
    class CollectingLogger
      attr_reader :events

      def initialize
        @events = []
        @mut = Mutex.new
      end

      def log(event_type, data = {})
        now = Time.now
        @mut.synchronize {
          @events << [now, event_type, data]
        }
        self
      end
    end
  end
end
