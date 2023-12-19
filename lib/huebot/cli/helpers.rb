require 'optparse'
require 'yaml'

module Huebot
  module CLI
    module Helpers
      #
      # Returns the command given to huebot.
      #
      # @return [Symbol]
      #
      def self.get_cmd
        ARGV[0].to_s.to_sym
      end

      def self.get_args(min: nil, max: nil, num: nil)
        args = ARGV[1..]
        if num
          if num != args.size
            $stderr.puts "Expected #{num} args, found #{args.size}"
            exit 1
          end
        elsif min and max
          if args.size < min or args.size > max
            $stderr.puts "Expected #{min}-#{max} args, found #{args.size}"
          end
        elsif min
          if args.size < min
            $stderr.puts "Expected at least #{num} args, found #{args.size}"
            exit 1
          end
        elsif max
          if args.size > max
            $stderr.puts "Expected no more than #{num} args, found #{args.size}"
            exit 1
          end
        end
        args
      end

      #
      # Parses and returns input from the CLI. Serious errors might result in the program exiting.
      #
      # @return [Huebot::CLI::Options] All given CLI options
      # @return [Array<Huebot::Program::Src>] Array of given program sources
      #
      def self.get_input!
        options, parser = option_parser
        parser.parse!

        files = ARGV[1..-1]
        if (bad_paths = files.select { |p| !File.exist? p }).any?
          $stderr.puts "Cannot find #{bad_paths.join ', '}"
          exit 1
        end

        sources = files.map { |path|
          src = YAML.load_file(path)
          version = (src.delete("version") || 1.0).to_f
          Program::Src.new(src, path, version)
        }

        if options.read_stdin
          src = YAML.load($stdin.read)
          version = (src.delete("version") || 1.0).to_f
          sources << Program::Src.new(src, "STDIN", version)
        end
        return options, sources
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
          print_messages! io, "Unknown lights", missing_lights
        end

        all_groups = programs.reduce([]) { |acc, p| acc + p.group_names }
        if (missing_groups = device_mapper.missing_groups all_groups).any?
          print_messages! io, "Unknown groups", missing_groups
        end

        all_vars = programs.reduce([]) { |acc, p| acc + p.device_refs }
        if (missing_vars = device_mapper.missing_vars all_vars).any?
          print_messages! io, "Unknown device inputs", missing_vars.map { |d| "$#{d}" }
        end

        invalid_devices = missing_lights.size + missing_groups.size + missing_vars.size
        return invalid_progs.any?, imperfect_progs.any?, invalid_devices > 0
      end

      # Print help and exit
      def self.help!
        _, parser = option_parser
        puts parser.help
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

      def self.option_parser
        options = Options.new([], false)
        parser = OptionParser.new { |opts|
          opts.banner = %(
  List all lights and groups:
      huebot ls

  Run program(s):
      huebot run file1.yml [file2.yml [file3.yml ...]] [options]

  Run a program from stdin:
      cat prog.yaml | huebot run
      huebot run -

  Validate programs and inputs:
      huebot check file1.yml [file2.yml [file3.yml ...]] [options]

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
          opts.on("-h", "--help", "Prints this help") { puts opts; exit }
        }
        return options, parser
      end
    end
  end
end
