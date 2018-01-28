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

    def execute(program, devices)
      transition devices, program.initial_state if program.initial_state

      if program.transitions.any?
        if program.loop?
          loop { iterate devices, program.transitions }
        elsif program.loops > 0
          program.loops.times { iterate devices, program.transitions }
        else
          iterate devices, program.transitions
        end
      end

      transition devices, program.final_state if program.final_state
    end

    private

    def iterate(device, transitions)
      transitions.each do |t|
        transition device, t
      end
    end

    def transition(devices, t)
      time = t["time"] || 4
      state = {transitiontime: time}
      state[:on] = t["switch"] if t.has_key? "switch"
      state[:hue] = t["hue"] if t.has_key? "hue"
      state[:brightness] = t["brightness"] if t.has_key? "brightness"
      state[:saturation] = t["saturation"] if t.has_key? "saturation"
      state[:xy] = t["xy"] if t.has_key? "xy"
      state[:color_temperature] = t["color_temperature"] if t.has_key? "color_temperature"
      state[:alert] = t["alert"] if t.has_key? "alert"
      state[:effect] = t["effect"] if t.has_key? "effect"
      state[:color_mode] = t["color_mode"] if t.has_key? "color_mode"
      devices.map { |device|
        Thread.new {
          device.set_state state
          wait time
          wait t["wait"] if t["wait"]
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
