module Huebot
  module Compiler
    class ApiV1
      DEVICE_REF = /\A\$([1-9][0-9]*)\Z/
      TRANSITION_KEYS = ["transition"]
      SERIAL_KEYS = ["serial"]
      PARALLEL_KEYS = ["parallel"]

      def initialize(api_version)
        @api_version = api_version
      end

      # @return [Huebot::Program]
      def build(tokens, default_name = nil)
        prog = Program.new
        prog.name = tokens.delete("name") || default_name
        prog.api_version = @api_version
        prog.data = node tokens.dup
        prog
      end

      private

      def node(t, inherited_devices = nil)
        errors, warnings = [], []
        instruction, child_nodes =
          case t.keys
          when TRANSITION_KEYS
            build_transition t.fetch("transition"), errors, warnings, inherited_devices
          when SERIAL_KEYS
            build_serial t.fetch("serial"), errors, warnings, inherited_devices
          when PARALLEL_KEYS
            build_parallel t.fetch("parallel"), errors, warnings, inherited_devices
          else
            errors << "Expected exactly one of: transition, serial, parallel. Found #{t.keys}"
            Program::AST::NoOp
          end
        Program::AST::Node.new(instruction, child_nodes, errors, warnings)
      end

      def build_transition(t, errors, warnings, inherited_devices = nil)
        state = build_state(t, errors, warnings)
        devices = build_devices(t, errors, warnings, inherited_devices)
        slp = build_sleep(t, errors, warnings)

        errors << "'transition' requires devices" if devices.empty?
        errors << "Unknown keys in 'transition': #{t.keys.join ", "}" if t.keys.any?

        instruction = Program::AST::Transition.new(state, devices, slp)
        return instruction, []
      end

      def build_serial(t, errors, warnings, inherited_devices = nil)
        lp = build_loop(t, errors, warnings)
        slp = build_sleep(t, errors, warnings)
        devices = build_devices(t, errors, warnings, inherited_devices)
        children = build_steps(t, errors, warnings, devices)

        errors << "'serial' requires steps" if children.empty?
        errors << "Unknown keys in 'serial': #{t.keys.join ", "}" if t.keys.any?

        instruction = Program::AST::SerialControl.new(lp, slp)
        return instruction, children
      end

      def build_parallel(t, errors, warnings, inherited_devices = nil)
        lp = build_loop(t, errors, warnings)
        slp = build_sleep(t, errors, warnings)
        devices = build_devices(t, errors, warnings, inherited_devices)
        children = build_steps(t, errors, warnings, devices)

        errors << "'parallel' requires steps" if children.empty?
        errors << "Unknown keys in 'parallel': #{t.keys.join ", "}" if t.keys.any?

        instruction = Program::AST::ParallelControl.new(lp, slp)
        return instruction, children
      end

      def map_state_keys(t, errors, warnings)
        state = HUE_STATE_KEYS.each_with_object({}) { |key, obj|
          obj[key] = t.delete key if t.has_key? key
        }

        state["transitiontime"] = t.delete("time").to_f.round(1) * 10 if t["time"]
        state["transitiontime"] = 4 if obj["transitiontime"].to_f < 0.1

        warnings << "Unknown keys in 'transition.state': #{t.keys.join ", "}" if t.keys.any?
        state
      end

      def build_state(t, errors, warnings)
        state = t.delete "state"
        case state
        when Hash
          map_state_keys state, errors, warnings
        when nil
          errors << "'state' is required in a transition"
          {}
        else
          errors << "Expected 'state' to be an object, got a #{state.class.name}"
          {}
        end
      end

      def build_steps(t, errors, warnings, inherited_devices = nil)
        steps_val = t.delete "steps"
        case steps_val
        when Array
          steps_val.map { |s| node s, inherited_devices }
        when nil
          errors << "Missing 'steps'"
          []
        else
          errors << "'steps' should be an array but is a #{steps_val.class.name}"
          []
        end
      end

      def build_loop(t, errors, warnings)
        loop_val = t.delete "loop"
        case loop_val
        when true
          Program::AST::Loop.new(Float::INFINITY)
        when false, nil
          Program::AST::Loop.new(1)
        when Integer
          Program::AST::Loop.new(loop_val)
        when Hash
          hours = loop_val.delete "hours"
          minutes = loop_val.delete "minutes"

          errors << "'loop.hours' must be an integer" if hours and !hours.is_a? Integer
          errors << "'loop.minutes' must be an integer" if minutes and !minutes.is_a? Integer
          errors << "If 'loop' is an object it must contain 'hours' and/or 'minutes'" if !hours and !minutes
          errors << "Unknown keys in loop: #{loop_val.keys.join ", "}" if loop_val.keys.any?

          Program::AST::Loop.new(nil, hours, minutes)
        else
          errors << "'loop' must be a boolean, an integer, or an object with 'hours' and/or 'minutes'"
          Program::AST::Loop.new(1)
        end
      end

      def build_sleep(t, errors, warnings)
        sleep_val = t.delete "sleep"
        case sleep_val
        when Integer, Float
          sleep_val
        when nil
          nil
        else
          errors << "'sleep' must be an integer or float"
          nil
        end
      end

      def build_devices(t, errors, warnings, inherited_devices = nil)
        devices_ref = t.delete("devices") || {}
        return inherited_devices if devices_ref.empty? and inherited_devices

        refs_val, lights_val, groups_val = devices_ref.delete("inputs"), devices_ref.delete("lights"), devices_ref.delete("groups")
        lights = lights_val ? device_names(Program::AST::Light, "lights", lights_val, errors, warnings) : []
        groups = groups_val ? device_names(Program::AST::Group, "groups", groups_val, errors, warnings) : []
        refs =
          case refs_val
          when "$all"
            [Program::AST::DeviceRef.new(:all)]
          when nil
            []
          when Array
            if refs_val.all? { |ref| ref.is_a?(String) && ref =~ DEVICE_REF }
              refs_val.map { |ref|
                n = ref.match(DEVICE_REF).captures[0].to_i
                Program::AST::DeviceRef.new(n)
              }
            else
              errors << "If 'inputs' is an array, it must be an array of input variables (e.g. [$1, $2, ...])"
              []
            end
          else
            errors << "'inputs' must be '$all' or an array of input variables (e.g. [$1, $2, ...])"
            []
          end

        errors << "Unknown keys in 'devices': #{devices_ref.keys.join ", "}" if devices_ref.keys.any?
        lights + groups + refs
      end

      def device_names(type, key, val, errors, warnings)
        if val.is_a?(Array) and val.all? { |name| name.is_a? String }
          val.map { |name| type.new(name) }
        else
          errors << "'#{key}' must be an array of names (found #{val.class.name})"
          []
        end
      end
    end
  end
end
