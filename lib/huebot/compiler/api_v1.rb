module Huebot
  module Compiler
    class ApiV1
      DEVICE_REF = /\A\$([1-9][0-9]*)\Z/

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

      def node(t, inherited_devices = [])
        transition = t.delete "transition"
        serial = t.delete "serial"
        parallel = t.delete "parallel"
        lp = t.delete "loop"
        slp = t.delete "sleep"
        devices = t.delete("devices")

        errors, warnings = [], []
        errors << "Only one of 'serial' and 'parallel' may be used in a step" if serial and parallel
        errors << "'serial' must be an array" if serial and !serial.is_a? Array
        errors << "'parallel' must be an array" if parallel and !parallel.is_a? Array
        errors << "A step with 'serial' or 'parallel' may not contain a transition" if transition and (serial or parallel)
        errors << "Only a 'serial' or 'parallel' step may define 'loop'" if lp and !serial and !parallel
        errors << "Transition requires devices" if transition and devices.nil? and inherited_devices.nil?
        errors << "'sleep' must be an integer or float" if slp and !slp.is_a?(Integer) and !slp.is_a?(Float)
        errors << "Unknown keys in step: #{t.keys.join ", "}" if t.keys.any?

        devices = devices ? build_devices(devices, errors, warnings) : inherited_devices
        instruction, child_nodes =
          if transition
            build_transition(transition, devices, slp, errors, warnings)
          elsif serial
            lp = build_loop(lp || {"count" => 1}, errors, warnings)
            build_serial(serial, lp, devices, slp, errors, warnings)
          elsif parallel
            lp = build_loop(lp || {"count" => 1}, errors, warnings)
            build_parallel(parallel, lp, devices, slp, errors, warnings)
          else
            errors << "No transition, serial, or parallel"
            Program::AST::NoOp
          end

        Program::AST::Node.new(instruction, child_nodes, errors, warnings)
      end

      def build_transition(transition, devices, slp, errors, warnings)
        node = Program::AST::Transition.new(transition, devices, slp)
        return node, []
      end

      def build_serial(serial, lp, devices, slp, errors, warnings)
        node = Program::AST::SerialControl.new(lp, slp)
        children = serial.is_a?(Array) ? serial.map { |t| node t, devices } : []
        return node, children
      end

      def build_parallel(parallel, lp, devices, slp, errors, warnings)
        node = Program::AST::ParallelControl.new(lp, slp)
        children = parallel.is_a?(Array) ? parallel.map { |t| node t, devices } : []
        return node, children
      end

      def build_loop(t, errors, warnings)
        case t
        when true
          Program::AST::Loop.new(Float::INFINITY)
        when false
          Program::AST::Loop.new(1)
        when Hash
          count = t.delete "count"
          hours = t.delete "hours"
          minutes = t.delete "minutes"

          errors << "'loop.count' must be an integer" if count and !count.is_a? Integer
          errors << "'loop.hours' must be an integer" if hours and !hours.is_a? Integer
          errors << "'loop.minutes' must be an integer" if minutes and !minutes.is_a? Integer
          errors << "'loop' must contain 'count' or 'hours'/'minutes'" if !count and !hours and !minutes
          errors << "Unknown keys in loop: #{t.keys.join ", "}" if t.keys.any?
          warnings << "'loop' should not specify both a count and hours/minutes" if count and (hours or minutes)

          Program::AST::Loop.new(count, hours, minutes)
        else
          errors << "'loop' must be a boolean or an object with 'count' or 'hours' and/or 'minutes'"
          Program::AST::Loop.new(1)
        end
      end

      def build_devices(t, errors, warnings)
        if !t.is_a? Hash
          errors << "'devices' must be an object"
          return []
        end

        inputs_val = t.delete "inputs"
        lights = t.delete "lights"
        groups = t.delete "groups"

        errors << "'devices.lights' must be an array of strings" if lights and (!lights.is_a?(Array) or !lights.all? { |l| l.is_a? String })
        errors << "'devices.groups' must be an array of strings" if groups and (!groups.is_a?(Array) or !groups.all? { |l| l.is_a? String })
        errors << "Unknown keys in 'devices': #{t.keys.join ", "}" if t.keys.any?

        inputs =
          case inputs_val
          when "$all"
            [Program::AST::DeviceRef.new(:all)]
          when Array
            if inputs_val.all? { |ref| ref.is_a?(String) && ref =~ DEVICE_REF }
              inputs_val.map { |ref|
                n = ref.match(DEVICE_REF).captures[0].to_i
                Program::AST::DeviceRef.new(n)
              }
            else
              errors << "If 'devices.inputs' is an array, it must be an array of input variables (e.g. [$1, $2, ...])"
              []
            end
          when nil
            []
          else
            errors << "'devices.inputs' must be '$all' or an array of input variables (e.g. [$1, $2, ...])"
            []
          end

        inputs + \
          (lights || []).map { |x| Program::AST::Light.new(x) } + \
          (groups || []).map { |x| Program::AST::Group.new(x) }
      end
    end
  end
end
