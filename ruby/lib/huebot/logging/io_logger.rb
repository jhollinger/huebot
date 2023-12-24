require 'json'

module Huebot
  module Logging
    class IOLogger
      def initialize(io)
        @io = io
        @mut = Mutex.new
      end

      def log(event_type, data = {})
        ts = Time.now.iso8601
        @mut.synchronize {
          @io.puts "#{ts} #{event_type} #{data.to_json}"
        }
      end
    end
  end
end
