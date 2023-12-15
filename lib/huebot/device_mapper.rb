module Huebot
  class DeviceMapper
    Unmapped = Class.new(Error)

    def initialize(bridge, inputs = [])
      all_lights, all_groups = bridge.lights, bridge.groups

      @lights_by_id = all_lights.reduce({}) { |a, l| a[l.id] = l; a }
      @lights_by_name = all_lights.reduce({}) { |a, l| a[l.name] = l; a }
      @groups_by_id = all_groups.reduce({}) { |a, g| a[g.id] = g; a }
      @groups_by_name = all_groups.reduce({}) { |a, g| a[g.name] = g; a }
      @devices_by_var = inputs.each_with_index.each_with_object({}) { |(x, idx), obj|
        obj[idx + 1] =
          case x
          when Light::Input then @lights_by_id[x.val.to_i] || @lights_by_name[x.val]
          when Group::Input then @groups_by_id[x.val.to_i] || @groups_by_name[x.val]
          else raise Error, "Invalid input: #{x}"
          end || raise(Unmapped, "Could not find #{x.class.name[8..-6].downcase} with id or name '#{x.val}'")
      }
      @all = @devices_by_var.values
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
