module Huebot
  class Compiler
    DEVICE_FIELDS = %i(light lights group groups device devices).freeze

    def initialize(device_mapper)
      @device_mapper = device_mapper
    end

    #
    # Build a huebot program from an intermediate representation (a Hash).
    #
    # @param ir [Hash]
    # @param default_name [String] A name to use if one isn't specified
    # @return [Huebot::Program]
    #
    def build(ir, default_name = nil)
      ir = ir.clone
      prog = Huebot::Program.new
      prog.name = ir.delete("name") || default_name

      # loop/loops
      val_loop = ir.delete("loop") || ir.delete(:loop)
      prog.errors << "'loop' must be 'true' or 'false'." if !val_loop.nil? and ![true, false].include?(val_loop)
      prog.loop = val_loop == true

      val_loops = ir.delete("loops") || ir.delete(:loops)
      prog.errors << "'loops' must be a positive integer." if !val_loops.nil? and val_loops.to_i < 0
      prog.loops = val_loops.to_i

      prog.errors << "'loop' and 'loops' are mutually exclusive." if prog.loop? and prog.loops > 0

      # initial state
      if (val_init = ir.delete("initial") || ir.delete(:initial))
        errors, warnings, state = build_transition val_init
        prog.initial_state = state
        prog.errors += errors
        prog.warnings += warnings
      end

      # transitions
      if (val_trns = ir.delete("transitions") || ir.delete(:transitions))
        val_trns.each do |val_trn|
          errors, warnings, state = if val_trn["parallel"] || val_trn[:parallel]
                                      build_parallel_transition val_trn
                                    else
                                      build_transition val_trn
                                    end
          prog.transitions << state
          prog.errors += errors
          prog.warnings += warnings
        end
      end

      # final state
      if (val_fnl = ir.delete("final") || ir.delete(:final))
        errors, warnings, state = build_transition val_fnl
        prog.final_state = state
        prog.errors += errors
        prog.warnings += warnings
      end

      # be strict about extra crap
      if (unknown = ir.keys.map(&:to_s)).any?
        prog.errors << "Unrecognized values: #{unknown.join ', '}."
      end

      # Add any warnings
      prog.warnings << "'final' is defined but will never be reached because 'loop' is 'true'." if prog.final_state and prog.loop?

      prog
    end

    private

    def build_parallel_transition(t)
      errors, warnings = [], []
      transition = Huebot::Program::ParallelTransition.new(0, [])

      transition.wait = t.delete("wait") || t.delete(:wait)
      errors << "'wait' must be a positive integer." if transition.wait and transition.wait.to_i <= 0

      parallel = t.delete("parallel") || t.delete(:parallel)
      if !parallel.is_a? Array
        errors << "'parallel' must be an array of transitions"
      else
        parallel.each do |sub_t|
          sub_errors, sub_warnings, sub_transition = build_transition(sub_t)
          errors += sub_errors
          warnings += sub_warnings
          transition.children << sub_transition
        end
      end

      return errors, warnings, transition
    end

    def build_transition(t)
      errors, warnings = [], []
      transition = Huebot::Program::Transition.new
      transition.devices = []

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

      transition.wait = t.delete("wait") || t.delete(:wait)
      errors << "'wait' must be a positive integer." if transition.wait and transition.wait.to_i <= 0

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
      return errors, warnings, transition
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
