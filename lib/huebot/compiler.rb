module Huebot
  module Compiler
    #
    # Build a huebot program from an intermediate representation (a Hash).
    #
    # @param ir [Hash]
    # @param default_name [String] A name to use if one isn't specified
    # @return [Huebot::Program]
    #
    def self.compile(ir, default_name = nil)
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
          errors, warnings, state = build_transition val_trn
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

    def self.build_transition(t)
      errors, warnings = [], []
      transition = Huebot::Program::Transition.new

      transition.wait = t.delete("wait") || t.delete(:wait)
      errors << "'wait' must be a positive integer." if transition.wait and transition.wait.to_i < 0

      state = {}
      if !(switch = t.delete("switch") || t.delete(:switch)).nil?
        state[:on] = case switch
                     when true, :on then true
                     when false, :off then false
                     else
                       errors << "Unrecognized 'switch' value '#{switch}'."
                       nil
                     end
      end
      state[:transitiontime] = t.delete("time") || t.delete(:time) || t.delete("transitiontime") || t.delete(:transitiontime) || 4

      transition.state = t.merge(state).reduce({}) { |a, (key, val)|
        a[key.to_sym] = val
        a
      }
      return errors, warnings, transition
    end
  end
end
