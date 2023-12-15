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

    # Returns all light names hard-coded into the program
    def light_names(node = data)
      devices(AST::Light).uniq.map(&:name)
    end

    # Returns all group names hard-coded into the program
    def group_names(node = data)
      devices(AST::Group).uniq.map(&:name)
    end

    # Returns all device refs (e.g. $all, $1, $2) in the program
    def device_refs(node = data)
      devices(AST::DeviceRef).uniq.map(&:ref)
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

    def devices(type, node = data)
      case node.instruction
      when AST::Transition
        node.instruction.devices.select { |d| d.is_a? type }
      when AST::SerialControl, AST::ParallelControl
        node.children.map { |n| devices type, n }.flatten
      else
        []
      end
    end
  end
end
