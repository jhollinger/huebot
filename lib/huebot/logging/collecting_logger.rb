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
          @events << [event_type, data, now]
        }
        self
      end
    end
  end
end
