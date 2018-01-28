module Huebot
  class Bot
    attr_reader :client

    Error = Class.new(StandardError)

    def initialize(client)
      @client = client
    end

    def find!(inputs)
      all_lights, all_groups = client.lights, client.groups

      lights_by_id = all_lights.reduce({}) { |a, l| a[l.id] = l; a }
      lights_by_name = all_lights.reduce({}) { |a, l| a[l.name] = l; a }
      groups_by_id = all_groups.reduce({}) { |a, g| a[g.id] = g; a }
      groups_by_name = all_groups.reduce({}) { |a, g| a[g.name] = g; a }

      inputs.map { |x|
        case x
        when LightInput then lights_by_id[x.val] || lights_by_name[x.val]
        when GroupInput then groups_by_id[x.val] || groups_by_name[x.val]
        else raise "Invalid input: #{x}"
        end || raise(Error, "Could not find #{x.class.name[8..-6].downcase} with id or name '#{x.val}'")
      }
    end

    def execute(program, inputs)
      transition inputs, program.initial_state if program.initial_state

      if program.transitions.any?
        if program.loop?
          loop { iterate inputs, program.transitions }
        elsif program.loops > 0
          program.loops.times { iterate inputs, program.transitions }
        else
          iterate inputs, program.transitions
        end
      end

      transition inputs, program.final_state if program.final_state
    end

    private

    def iterate(input, transitions)
      transitions.each do |t|
        transition input, t
      end
    end

    def transition(inputs, t)
      time = t.state[:transitiontime] || 4
      inputs.map { |input|
        Thread.new {
          input.set_state t.state
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
