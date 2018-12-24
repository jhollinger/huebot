module Huebot
  class DeviceMapper
    Unmapped = Class.new(StandardError)

    def initialize(client, inputs = [])
      all_lights, all_groups = client.lights, client.groups

      @lights_by_id = all_lights.reduce({}) { |a, l| a[l.id] = l; a }
      @lights_by_name = all_lights.reduce({}) { |a, l| a[l.name] = l; a }
      @groups_by_id = all_groups.reduce({}) { |a, g| a[g.id] = g; a }
      @groups_by_name = all_groups.reduce({}) { |a, g| a[g.name] = g; a }
      @devices_by_var = inputs.each_with_index.reduce({}) { |a, (x, idx)|
        dev = case x
              when LightInput then @lights_by_id[x.val] || @lights_by_name[x.val]
              when GroupInput then @groups_by_id[x.val] || @groups_by_name[x.val]
              else raise "Invalid input: #{x}"
              end || raise(Unmapped, "Could not find #{x.class.name[8..-6].downcase} with id or name '#{x.val}'")
        a["$#{idx + 1}"] = dev
        a
      }
      @all = @devices_by_var.values
    end

    def light!(id)
      case id
      when Integer
        @lights_by_id[id]
      when String
        @lights_by_name[id]
      end || (raise Unmapped, "Unmapped light '#{id}'")
    end

    def group!(id)
      case id
      when Integer
        @groups_by_id[id]
      when String
        @groups_by_name[id]
      end || (raise Unmapped, "Unmapped group '#{id}'")
    end

    def var!(id)
      case id
      when "$all"
        @all
      else
        @devices_by_var[id]
      end || (raise Unmapped, "Unmapped device '#{id}'")
    end
  end
end
