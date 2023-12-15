module Huebot
  class Program
    #
    # Struct for storing a program's Intermediate Representation and source filepath.
    #
    # @attr tokens [Hash]
    # @attr filepath [String]
    # @attr api_version [Float] API version
    #
    Src = Struct.new(:tokens, :filepath, :api_version) do
      def default_name
        File.basename(filepath, ".*")
      end
    end

    module AST
      Node = Struct.new(:instruction, :children, :errors, :warnings)

      Transition = Struct.new(:state, :devices, :sleep)
      SerialControl = Struct.new(:loop, :sleep)
      ParallelControl = Struct.new(:loop, :sleep)

      Loop = Struct.new(:count, :hours, :minutes)
      DeviceRef = Struct.new(:ref)
      Light = Struct.new(:name)
      Group = Struct.new(:name)
      NoOp = :NoOp
    end

    attr_accessor :name
    attr_accessor :api_version
    attr_accessor :data

    def valid?
      errors.empty?
    end

    def call
      data.call
    end

    def device_refs(node = data)
      case node.instruction
      when AST::Transition
        node.instruction.devices.select { |d| d.is_a? AST::DeviceRef }.map(&:ref)
      when AST::SerialControl, AST::ParallelControl
        node.children.map { |n| device_refs n }.flatten
      else
        []
      end.uniq
    end

    def errors(node = data)
      node.children.reduce(node.errors) { |errors, child|
        errors + child.errors
      }
    end

    def warnings(node = data)
      node.children.reduce(node.warnings) { |warnings, child|
        warnings + child.warnings
      }
    end

    private

    def exec(i)
      case i
      when Serial
        serial_transitions i.transitions, i.loop
      when Parallel
        parallel_transitions i.transitions
      when Transition
        transition i.state, i.devices
      when Sleep
        wait (i.sec * 10).round
      else
        raise Error, "Unexpected instruction '#{i.class.name}'"
      end
    end

      def serial_transitions(transitions, lp)
        perform(lp) {
          transitions.each { |t| transition t }
        }
      end

      def parallel_transitions(transitions)
        transactions
          .map { |t| Thread.new { transition t } }
          .map(&:join)
      end

      def transition(state, devices)
        time = state[:transitiontime] || 4
        devices.map { |device|
          Thread.new {
            device.set_state state
            wait time
          }
        }.map(&:join)
      end

      def perform(lp)
      end

      def wait(tens_of_sec)
        ms = tens_of_sec * 100
        seconds = ms / 1000.to_f
        # TODO sleep in small bursts in a loop so can detect if an Interrupt was caught
        sleep seconds
      end
  end
end
