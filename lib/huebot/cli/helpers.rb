require 'optparse'
require 'yaml'
require 'json'

module Huebot
  module CLI
    module Helpers
      DEFAULT_API_VERSION = 1.2

      #
      # Returns the command given to huebot.
      #
      # @return [Symbol]
      #
      def self.get_cmd(argv = ARGV)
        argv[0].to_s.to_sym
      end

      def self.get_args!(argv = ARGV, min: nil, max: nil, num: nil)
        args, error = get_args(argv, min: min, max: max, num: num)
        if error
          $stderr.puts error
          exit 1
        end
        args
      end

      def self.get_args(argv = ARGV, min: nil, max: nil, num: nil)
        args = argv[1..]
        if num
          if num != args.size
            return nil, "Expected #{num} args, found #{args.size}"
          end
        elsif min and max
          if args.size < min or args.size > max
            return nil, "Expected #{min}-#{max} args, found #{args.size}"
          end
        elsif min
          if args.size < min
            return nil, "Expected at least #{min} args, found #{args.size}"
          end
        elsif max
          if args.size > max
            return nil, "Expected no more than #{max} args, found #{args.size}"
          end
        end
        return args, nil
      end

      #
      # Parses and returns input from the CLI. Serious errors might result in the program exiting.
      #
      # @param opts [Huebot::CLI::Options] All given CLI options
      # @return [Array<Huebot::Program::Src>] Array of given program sources
      #
      def self.get_input!(opts, argv = ARGV)
        files = argv[1..-1]
        if (bad_paths = files.select { |p| !File.exist? p }).any?
          opts.stderr.puts "Cannot find #{bad_paths.join ', '}"
          return []
        end

        sources = files.map { |path|
          ext = File.extname path
          src =
            case ext
            when ".yaml", ".yml"
              YAML.safe_load(File.read path) || {}
            when ".json"
              JSON.load(File.read path) || {}
            else
              opts.stderr.puts "Unknown file extension '#{ext}'. Expected .yaml, .yml, or .json"
              return []
            end
          version = (src.delete("version") || DEFAULT_API_VERSION).to_f
          Program::Src.new(src, path, version)
        }

        if !opts.stdin.isatty or opts.read_stdin
          opts.stdout.puts "Please enter your YAML or JSON Huebot program below, followed by Ctrl+d:" if opts.read_stdin
          raw = opts.stdin.read.lstrip
          src = raw[0] == "{" ? JSON.load(raw) : YAML.safe_load(raw)

          opts.stdout.puts "Executing..." if opts.read_stdin
          version = (src.delete("version") || DEFAULT_API_VERSION).to_f
          sources << Program::Src.new(src, "STDIN", version)
        end
        sources
      end

      #
      # Prints any program errors or warnings, and returns a boolean for each.
      #
      # @param programs [Array<Huebot::Program>]
      # @param device_mapper [Huebot::DeviceMapper]
      # @param io [IO] Usually $stdout or $stderr
      # @param quiet [Boolean] if true, don't print anything
      #
      def self.check!(programs, device_mapper, io, quiet: false)
        if (invalid_progs = programs.select { |prog| prog.errors.any? }).any?
          errors = invalid_progs.reduce([]) { |acc, prog|
            acc + prog.errors.map { |e| "  #{prog.name}: #{e}" }
          }
          print_messages! io, "Errors", errors unless quiet
        end

        if (imperfect_progs = programs.select { |prog| prog.warnings.any? }).any?
          warnings = imperfect_progs.reduce([]) { |acc, prog|
            acc + prog.warnings.map { |e| "  #{prog.name}: #{e}" }
          }
          print_messages! io, "Warnings", warnings unless quiet
        end

        all_lights = programs.reduce([]) { |acc, p| acc + p.light_names }
        if (missing_lights = device_mapper.missing_lights all_lights).any?
          print_messages! io, "Unknown lights", missing_lights unless quiet
        end

        all_groups = programs.reduce([]) { |acc, p| acc + p.group_names }
        if (missing_groups = device_mapper.missing_groups all_groups).any?
          print_messages! io, "Unknown groups", missing_groups unless quiet
        end

        all_vars = programs.reduce([]) { |acc, p| acc + p.device_refs }
        if (missing_vars = device_mapper.missing_vars all_vars).any?
          print_messages! io, "Unknown device inputs", missing_vars.map { |d| "$#{d}" } unless quiet
        end

        invalid_devices = missing_lights.size + missing_groups.size + missing_vars.size
        return invalid_progs.any?, imperfect_progs.any?, invalid_devices > 0
      end

      def self.get_opts!
        opts = default_options
        parser = option_parser opts
        parser.parse!
        opts
      end

      # Print help and exit
      def self.help!
        opts = default_options
        parser = option_parser opts
        opts.stdout.puts parser.help
        exit 1
      end

      private

      #
      # Print each message (of the given type) for each program.
      #
      # @param io [IO] Usually $stdout or $stderr
      # @param label [String] Top-level for this group of messages
      # @param errors [Array<String>]
      #
      def self.print_messages!(io, label, errors)
        io.puts "#{label}:"
        errors.each_with_index { |msg, i|
          io.puts "  #{i+1}) #{msg}"
        }
      end

      def self.option_parser(options)
        OptionParser.new { |opts|
          opts.banner = %(
  List all lights and groups:
      huebot ls

  Run program(s):
      huebot run prog1.yaml [prog2.yml [prog3.json ...]] [options]

  Run program from STDIN:
      cat prog1.yaml | huebot run [options]
      huebot run [options] < prog1.yaml
      huebot run -i [options]

  Validate programs and inputs:
      huebot check prog1.yaml [prog2.yaml [prog3.yaml ...]] [options]

  Print the current state of the given lights and/or groups:
      huebot get-state [options]

  Manually set/clear the IP for your Hue Bridge (useful when on a VPN):
      huebot set-ip 192.168.1.20
      huebot clear-ip

  Clear all connection config:
    huebot unregister

  Options:
          ).strip
          opts.on("-lLIGHT", "--light=LIGHT", "Light ID or name") { |l| options.inputs << Light::Input.new(l) }
          opts.on("-gGROUP", "--group=GROUP", "Group ID or name") { |g| options.inputs << Group::Input.new(g) }
          opts.on("-i", "Read program from STDIN") { options.read_stdin = true }
          opts.on("--debug", "Print debug info during run") { options.debug = true }
          opts.on("--no-device-check", "Don't validate devices against the Bridge ('check' cmd only)") { options.no_device_check = true }
          opts.on("-h", "--help", "Prints this help") { options.stdout.puts opts; exit }
        }
      end

      def self.default_options
        options = Options.new([], false)
        options.stdin = $stdin
        options.stdout = $stdout
        options.stderr = $stderr
        options
      end
    end
  end
end
