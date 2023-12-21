module Huebot
  class DeviceMapper
    Unmapped = Class.new(Error)

    def initialize(lights: [], groups:[], inputs: [])
      @lights_by_id = lights.each_with_object({}) { |l, a| a[l.id] = l }
      @lights_by_name = lights.each_with_object({}) { |l, a| a[l.name] = l }
      @groups_by_id = groups.each_with_object({}) { |g, a| a[g.id] = g }
      @groups_by_name = groups.each_with_object({}) { |g, a| a[g.name] = g }
      @devices_by_var = inputs.each_with_index.each_with_object({}) { |(x, idx), obj|
        obj[idx + 1] =
          case x
          when Light::Input then @lights_by_id[x.val.to_i] || @lights_by_name[x.val]
          when Group::Input then @groups_by_id[x.val.to_i] || @groups_by_name[x.val]
          else raise Error, "Invalid input: #{x}"
          end || raise(Unmapped, "Could not find #{x.class.name[8..-8].downcase} with id or name '#{x.val}'")
      }
      @all = @devices_by_var.values
    end

    def each
      if block_given?
        @all.each { |device| yield device }
      else
        @all.each
      end
    end

    def light!(id)
      @lights_by_id[id] || @lights_by_name[id] || (raise Unmapped, "Unmapped light '#{id}'")
    end

    def group!(id)
      @groups_by_id[id] || @groups_by_name[id] || (raise Unmapped, "Unmapped group '#{id}'")
    end

    def var!(id)
      case id
      when :all
        @all
      else
        @devices_by_var[id] || (raise Unmapped, "Unmapped device '#{id}'")
      end
    end

    def missing_lights(names)
      names - @lights_by_name.keys
    end

    def missing_groups(names)
      names - @groups_by_name.keys
    end

    def missing_vars(vars)
      missing = vars - @devices_by_var.keys
      if @all.any?
        missing - [:all]
      else
        missing
      end
    end
  end
end
