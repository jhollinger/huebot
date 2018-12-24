module Huebot
  class Bot
    attr_reader :client

    Error = Class.new(StandardError)

    def initialize(client)
      @client = client
    end

    def execute(program)
      transition program.initial_state if program.initial_state

      if program.transitions.any?
        if program.loop?
          loop { iterate program.transitions }
        elsif program.loops > 0
          program.loops.times { iterate program.transitions }
        else
          iterate program.transitions
        end
      end

      transition program.final_state if program.final_state
    end

    private

    def iterate(transitions)
      transitions.each do |t|
        if t.respond_to?(:children)
          parallel_transitions t
        else
          transition t
        end
      end
    end

    def parallel_transitions(t)
      t.children.map { |sub_t|
        Thread.new {
          transition sub_t
        }
      }.map(&:join)
      wait t.wait if t.wait and t.wait > 0
    end

    def transition(t)
      time = t.state[:transitiontime] || 4
      t.devices.map { |device|
        Thread.new {
          device.set_state t.state
          wait time
          wait t.wait if t.wait
        }
      }.map(&:join)
    end

    def wait(time)
      ms = time * 100
      seconds = ms / 1000.to_f
      # TODO sleep in small bursts in a loop so can detect if an Interrupt was caught
      sleep seconds
    end
  end
end
