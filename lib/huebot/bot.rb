module Huebot
  class Bot
    attr_reader :client

    Error = Class.new(StandardError)

    def initialize(client)
      @client = client
    end

    def execute(program)
      program.run
    end

    private

    def iterate(transitions)
      transitions.each do |t|
        if t.respond_to?(:children)
          parallel_transitions t
        else
          transition t
        end
      end
    end

    def parallel_transitions(t)
      t.children.map { |sub_t|
        Thread.new {
          transition sub_t
        }
      }.map(&:join)
      wait t.wait if t.wait and t.wait > 0
    end
  end
end
