module Huebot
  class Bot
    attr_reader :client

    Error = Class.new(StandardError)

    def initialize(client)
      @client = client
    end

    def find!(lights = [], groups = [])
      all_lights, all_groups = client.lights, client.groups
      lights_by_id = all_lights.reduce({}) { |a, l| a[l.id] = l; a }
      lights_by_name = all_lights.reduce({}) { |a, l| a[l.name] = l; a }
      groups_by_id = all_groups.reduce({}) { |a, g| a[g.id] = g; a }
      groups_by_name = all_groups.reduce({}) { |a, g| a[g.name] = g; a }

      lights.map { |l| lights_by_id[l] || lights_by_name[l] || raise(Error, "Could not a find light with id or name '#{l}'") } + \
      groups.map { |g| groups_by_id[g] || groups_by_name[g] || raise(Error, "Could not find a group with id or name '#{g}'") }
    end

    def execute!(programs, devices)
      programs.each do |prog|
        transition devices, prog.initial_state if prog.initial_state

        if prog.transitions.any?
          if prog.loop?
            loop { iterate devices, prog.transitions }
          elsif prog.loops > 0
            prog.loops.times { iterate devices, prog.transitions }
          else
            iterate devices, prog.transitions
          end
        end

        transition devices, prog.final_state if prog.final_state
      end
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
