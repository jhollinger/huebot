module Huebot
  module CLI
    module Runner
      def self.ls(lights, groups, opts)
        opts.stdout.puts "Lights\n" + lights.map { |l| "  #{l.id}: #{l.name}" }.join("\n") + \
          "\nGroups\n" + groups.map { |g| "  #{g.id}: #{g.name}" }.join("\n")
        return 0
      rescue ::Huebot::Error => e
        opts.stderr.puts "#{e.class.name}: #{e.message}"
        return 1
      rescue Interrupt
        return 130
      end

      def self.run(sources, lights, groups, opts)
        programs = sources.map { |src|
          Huebot::Compiler.build src
        }
        device_mapper = Huebot::DeviceMapper.new(lights: lights, groups: groups, inputs: opts.inputs)
        found_errors, _found_warnings, missing_devices = Helpers.check! programs, device_mapper, opts.stderr
        return 1 if found_errors || missing_devices

        logger = opts.debug ? Logging::IOLogger.new(opts.stdout) : nil
        bot = Huebot::Bot.new(device_mapper, logger: logger, waiter: opts.bot_waiter)
        programs.each { |prog| bot.execute prog }
        return 0
      rescue ::Huebot::Error => e
        opts.stderr.puts "#{e.class.name}: #{e.message}"
        return 1
      rescue Interrupt
        return 130
      end

      def self.check(sources, lights, groups, opts)
        programs = sources.map { |src|
          Huebot::Compiler.build src
        }

        # Assume all devices and inputs are correct
        if opts.no_device_check
          light_input_names = opts.inputs.select { |i| i.is_a? Light::Input }.map(&:val)
          lights = programs.reduce(light_input_names) { |acc, p| acc + p.light_names }.uniq.each_with_index.map { |name, i| Light.new(nil, i+1, {"name" => name}) }

          group_input_names = opts.inputs.select { |i| i.is_a? Group::Input }.map(&:val)
          groups = programs.reduce(group_input_names) { |acc, p| acc + p.group_names }.uniq.each_with_index.map { |name, i| Group.new(nil, i+1, {"name" => name}) }
        end

        device_mapper = Huebot::DeviceMapper.new(lights: lights, groups: groups, inputs: opts.inputs)
        found_errors, found_warnings, missing_devices = Helpers.check! programs, device_mapper, opts.stderr
        return (found_errors || found_warnings || missing_devices) ? 1 : 0
      rescue ::Huebot::Error => e
        opts.stderr.puts "#{e.class.name}: #{e.message}"
        return 1
      rescue Interrupt
        return 130
      end

      def self.get_state(lights, groups, opts)
        device_mapper = Huebot::DeviceMapper.new(lights: lights, groups: groups, inputs: opts.inputs)
        device_mapper.each do |device|
          opts.stdout.puts device.name
          opts.stdout.puts "  #{device.get_state}"
        end
        0
      rescue Interrupt
        return 130
      end

      def self.set_ip(config, ip, opts)
        config["ip"] = ip
        0
      rescue ::Huebot::Error => e
        opts.stderr.puts "#{e.class.name}: #{e.message}"
        return 1
      rescue Interrupt
        return 130
      end

      def self.clear_ip(config, opts)
        config["ip"] = nil
        0
      rescue ::Huebot::Error => e
        opts.stderr.puts "#{e.class.name}: #{e.message}"
        return 1
      rescue Interrupt
        return 130
      end

      def self.unregister(config, opts)
        config.clear
        0
      rescue ::Huebot::Error => e
        opts.stderr.puts "#{e.class.name}: #{e.message}"
        return 1
      rescue Interrupt
        return 130
      end
    end
  end
end
