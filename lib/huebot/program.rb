module Huebot
  class Program
    Transition = Struct.new(:wait, :state, :devices)
    ParallelTransition = Struct.new(:wait, :children)

    attr_accessor :name
    attr_accessor :initial_state
    attr_accessor :transitions
    attr_accessor :final_state
    attr_accessor :loop
    attr_accessor :loops
    attr_accessor :errors
    attr_accessor :warnings

    def initialize
      @name = nil
      @initial_state = nil
      @transitions = []
      @final_state = nil
      @loop = false
      @loops = 0
      @errors = []
      @warnings = []
    end

    def valid?
      errors.empty?
    end

    alias_method :loop?, :loop
  end
end
