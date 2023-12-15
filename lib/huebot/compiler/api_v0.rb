module Huebot
  module Compiler
    class ApiV0
      DEVICE_FIELDS = %i(light lights group groups device devices).freeze

      def initialize(api_version)
        @api_version = api_version
      end

      # @return [Huebot::Program]
      def build(tokens, default_name = nil)
        tokens = tokens.clone
        prog = Huebot::Program.new
        prog.name = tokens.delete("name") || default_name
        prog.api_version = @api_version

        # initial state
        if (val_init = tokens.delete("initial") || tokens.delete(:initial))
          errors, warnings, state, devices = build_transition val_init
          prog.errors += errors
          prog.warnings += warnings
          prog.instructions << Program::AST::Transition.new(state, devices)
        end

        # Main controller
        val_loop = tokens.delete("loop") || tokens.delete(:loop)
        prog.errors << "'loop' must be 'true' or 'false'." if !val_loop.nil? and ![true, false].include?(val_loop)
        infinite_loop = val_loop == true

        val_loops = tokens.delete("loops") || tokens.delete(:loops)
        prog.errors << "'loops' must be a positive integer." if !val_loops.nil? and val_loops.to_i < 0
        num_loops = val_loops.to_i

        prog.errors << "'loop' and 'loops' are mutually exclusive." if infinite_loop and num_loops > 0
        main_control_loop =
          if infinite_loop
            Loop.new
          elsif num_loops
            Loop.new(num_loops)
          else
            Loop.new(1)
          end

        main_controller = Program::AST::Serial.new([], main_control_loop)
        prog.instructions << main_controller

        # transitions
        if (val_trns = tokens.delete("transitions") || tokens.delete(:transitions))
          val_trns.each do |val_trn|
            errors, warnings, instructions =
              if val_trn["parallel"] || val_trn[:parallel]
                build_parallel_transitions val_trn
              else
                build_transition val_trn
              end
            prog.errors += errors
            prog.warnings += warnings
            prog.instructions += instructions
          end
        end

        # final state
        if (val_fnl = tokens.delete("final") || tokens.delete(:final))
          errors, warnings, instructions = build_transition val_fnl
          prog.errors += errors
          prog.warnings += warnings
          prog.instructions += instructions
        end

        # be strict about extra crap
        if (unknown = tokens.keys.map(&:to_s)).any?
          prog.errors << "Unrecognized values: #{unknown.join ', '}."
        end

        # Add any warnings
        # TODO
        #prog.warnings << "'final' is defined but will never be reached because 'loop' is 'true'." if prog.final_state and prog.loop?

        prog
      end

      private

      def build_parallel_transitions(t)
        errors, warnings, instructions = [], [], []
        controller = Program::AST::Parallel.new([])
        instructions << controller

        parallel = t.delete("parallel") || t.delete(:parallel)
        if !parallel.is_a? Array
          errors << "'parallel' must be an array of transitions"
        else
          parallel.each do |sub_t|
            sub_errors, sub_warnings, sub_transition = build_transition(sub_t)
            errors += sub_errors
            warnings += sub_warnings
            controller.transitions << sub_transition if sub_transition
          end
        end

        if (wait = t.delete("wait") || t.delete(:wait))
          wait = wait.to_i
          if wait > 0
            instructions << Program::AST::Sleep.new(wait)
          else
            errors << "'wait' must be a positive integer."
          end
        end

        return errors, warnings, transition
      end

      def build_transition(t)
        errors, warnings, instructions = [], [], []
        transition = Program::AST::Transition.new
        transition.devices = []
        instructions << transition

        map_devices(t, :light, :lights, :light!) { |map_errors, devices|
          errors += map_errors
          transition.devices += devices
        }

        map_devices(t, :group, :groups, :group!) { |map_errors, devices|
          errors += map_errors
          transition.devices += devices
        }

        map_devices(t, :device, :devices, :var!) { |map_errors, devices|
          errors += map_errors
          transition.devices += devices
        }
        errors << "Missing light/lights, group/groups, or device/devices" if transition.devices.empty?

        if (wait = t.delete("wait") || t.delete(:wait))
          wait = wait.to_i
          if wait > 0
            instructions << Program::AST::Sleep.new(wait)
          else
            errors << "'wait' must be a positive integer."
          end
        end

        state = {}
        switch = t.delete("switch")
        switch = t.delete(:switch) if switch.nil?
        if !switch.nil?
          state[:on] = case switch
                       when true, :on then true
                       when false, :off then false
                       else
                         errors << "Unrecognized 'switch' value '#{switch}'."
                         nil
                       end
        end
        state[:transitiontime] = t.delete("time") || t.delete(:time) || t.delete("transitiontime") || t.delete(:transitiontime) || 4

        transition.state = t.merge(state).each_with_object({}) { |(key, val), obj|
          key = key.to_sym
          obj[key] = val unless DEVICE_FIELDS.include? key
        }
        return errors, warnings, instructions
      end

      private

      def map_devices(t, singular_key, plural_key, ref_type)
        errors, devices = [], []

        key = t[singular_key.to_s] || t[singular_key]
        keys = t[plural_key.to_s] || t[plural_key]

        (Array(key) + Array(keys)).each { |x|
          begin
            devices += Array(@device_mapper.send(ref_type, x))
          rescue Huebot::DeviceMapper::Unmapped => e
            errors << e.message
          end
        }

        yield errors, devices
      end
    end
  end
end
