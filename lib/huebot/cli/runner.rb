module Huebot
  module CLI
    module Runner
      def self.ls(lights, groups, io = $stdout)
        puts "Lights\n" + lights.map { |l| "  #{l.id}: #{l.name}" }.join("\n") + \
          "\nGroups\n" + groups.map { |g| "  #{g.id}: #{g.name}" }.join("\n")
        return 0
      rescue ::Huebot::Error => e
        $stderr.puts "#{e.class.name}: #{e.message}"
        return 1
      end

      def self.run(sources, lights, groups, opts)
        device_mapper = Huebot::DeviceMapper.new(lights: lights, groups: groups, inputs: opts.inputs)
        programs = sources.map { |src|
          Huebot::Compiler.build src
        }
        found_errors, _found_warnings, missing_devices = Helpers.check! programs, device_mapper, $stderr
        return 1 if found_errors || missing_devices

        logger = opts.debug ? Logging::IOLogger.new($stdout) : nil
        bot = Huebot::Bot.new(device_mapper, logger: logger)
        programs.each { |prog| bot.execute prog }
        return 0
      rescue ::Huebot::Error => e
        $stderr.puts "#{e.class.name}: #{e.message}"
        return 1
      end

      def self.check(sources, lights, groups, opts)
        device_mapper = Huebot::DeviceMapper.new(lights: lights, groups: groups, inputs: opts.inputs)
        programs = sources.map { |src|
          Huebot::Compiler.build src
        }
        found_errors, found_warnings, missing_devices = Helpers.check! programs, device_mapper, $stdout
        return (found_errors || found_warnings || missing_devices) ? 1 : 0
      rescue ::Huebot::Error => e
        $stderr.puts "#{e.class.name}: #{e.message}"
        return 1
      end

      def self.get_state(lights, groups, inputs)
        device_mapper = Huebot::DeviceMapper.new(lights: lights, groups: groups, inputs: opts.inputs)
        device_mapper.each do |device|
          puts device.name
          puts "  #{device.get_state}"
        end
        0
      end

      def self.set_ip
        config = Huebot::Config.new
        config["ip"] = ip
        0
      rescue ::Huebot::Error => e
        $stderr.puts "#{e.class.name}: #{e.message}"
        return 1
      end

      def self.clear_ip
        config = Huebot::Config.new
        config["ip"] = nil
        0
      rescue ::Huebot::Error => e
        $stderr.puts "#{e.class.name}: #{e.message}"
        return 1
      end

      def self.unregister
        config = Huebot::Config.new
        config.clear
        0
      rescue ::Huebot::Error => e
        $stderr.puts "#{e.class.name}: #{e.message}"
        return 1
      end
    end
  end
end
