require 'optparse'
require 'ostruct'
require 'yaml'

module Huebot
  #
  # Helpers for running huebot in cli-mode.
  #
  module CLI
    #
    # Struct for storing cli options and program files.
    #
    # @attr inputs [Array<String>]
    #
    Options = Struct.new(:inputs, :read_stdin)

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
    # @return [Array<Huebot::ProgramSrc>] Array of given program sources
    #
    def self.get_input!
      options, parser = option_parser
      parser.parse!

      files = ARGV[1..-1]
      if files.empty? and !options.read_stdin
        puts parser.help
        exit 1
      elsif (bad_paths = files.select { |p| !File.exist? p }).any?
        $stderr.puts "Cannot find #{bad_paths.join ', '}"
        exit 1
      else
        sources = files.map { |path|
          ProgramSrc.new(YAML.load_file(path), path)
        }
        sources << ProgramSrc.new(YAML.load($stdin.read), "STDIN") if options.read_stdin
        return options, sources
      end
    end

    #
    # Prints any program errors or warnings, and returns a boolean for each.
    #
    # @param programs [Array<Huebot::Program>]
    # @param io [IO] Usually $stdout or $stderr
    # @param quiet [Boolean] if true, don't print anything
    #
    def self.check!(programs, io, quiet: false)
      if (invalid_progs = programs.select { |prog| prog.errors.any? }).any?
        print_messages! io, "Errors", invalid_progs, :errors unless quiet
      end

      if (imperfect_progs = programs.select { |prog| prog.warnings.any? }).any?
        puts "" if invalid_progs.any?
        print_messages! io, "Warnings", imperfect_progs, :warnings unless quiet
      end

      return invalid_progs.any?, imperfect_progs.any?
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
    # @param progs [Array<Huebot::CLI::Program>]
    # @param msg_type [Symbol] name of method that holds the messages (i.e. :errors or :warnings)
    #
    def self.print_messages!(io, label, progs, msg_type)
      io.puts "#{label}:"
      progs.each { |prog|
        io.puts "  #{prog.name}:"
        prog.send(msg_type).each_with_index { |msg, i| io.puts "    #{i+1}. #{msg}" }
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

Validate programs and inputs:
    huebot check file1.yml [file2.yml [file3.yml ...]] [options]

Manually set/clear the IP for your Hue Bridge (useful when on a VPN):
    huebot set-ip 192.168.1.20
    huebot clear-ip

Clear all connection config:
  huebot unregister

Options:
        ).strip
        opts.on("-lLIGHT", "--light=LIGHT", "Light ID or name") { |l| options.inputs << LightInput.new(l) }
        opts.on("-gGROUP", "--group=GROUP", "Group ID or name") { |g| options.inputs << GroupInput.new(g) }
        opts.on("--all", "All lights and groups TODO") { $stderr.puts "Not Implemented"; exit 1 }
        opts.on("-i", "Read program from STDIN") { options.read_stdin = true }
        opts.on("-h", "--help", "Prints this help") { puts opts; exit }
      }
      return options, parser
    end
  end
end
