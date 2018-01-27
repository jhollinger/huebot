module Huebot
  class Program
    attr_accessor :name
    attr_accessor :initial_state
    attr_accessor :transitions
    attr_accessor :final_state
    attr_accessor :loop
    attr_accessor :loops

    def initialize
      @name = nil
      @initial_state = nil
      @transitions = []
      @final_state = nil
      @loop = false
      @loops = 0
    end

    alias_method :loop?, :loop
  end
end
