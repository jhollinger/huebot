module Huebot
  module Compiler
    Error = Class.new(StandardError)

    #
    # Build a huebot program from an intermediate representation (a Hash).
    #
    # @param ir [Hash]
    # @param default_name [String] A name to use if one isn't specified
    # @return [Huebot::Program]
    #
    def self.compile!(ir, default_name = nil)
      ir = ir.clone
      prog = Huebot::Program.new
      prog.name = ir.delete("name") || default_name

      # Set loop or loops
      raise Error, "'loop' must be 'true' or 'false'" if ir.has_key?("loop") and ![true, false].include?(ir["loop"])
      raise Error, "'loops' must be a positive integer" if ir.has_key?("loops") and ir["loops"].to_i < 0
      prog.loop = ir.delete("loop") == true
      prog.loops = ir.delete("loops").to_i
      raise Error, "'loop' and 'loops' are mutually exclusive" if prog.loop? and prog.loops > 0

      # Set initial state
      if (init = ir.delete("initial"))
        prog.initial_state = init
      end

      # Set transitions
      if (trns = ir.delete("transitions"))
        prog.transitions = trns
      end

      # Set final state
      if (fnl = ir.delete("final"))
        prog.final_state = fnl
      end

      # Be strict about extra crap
      if (unknown = ir.keys).any?
        raise Error, "Unrecognized values: #{unknown.join ', '}"
      end

      prog
    end
  end
end
