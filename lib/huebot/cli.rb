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
    # @attr lights [Array<String>]
    # @attr groups [Array<String>]
    #
    Options = Struct.new(:lights, :groups)

    #
    # Struct for storing a program's Intermediate Representation and source filepath.
    #
    # @attr ir [Hash]
    # @attr filepath [String]
    #
    ProgramSrc = Struct.new(:ir, :filepath)

    #
    # Parses and returns input from the CLI. Serious errors might result in the program exiting.
    #
    # @return [Huebot::CLI::Options] All given CLI options
    # @return [Array<Huebot::CLI::ProgramSrc>] Array of given program sources
    #
    def self.get_input!
      options = Options.new([], [])
      parser = OptionParser.new { |opts|
        opts.banner = "Usage: huebot file1.yml [file2.yml [file3.yml ...]] [options]"
        opts.on("-lLIGHT", "--light=LIGHT", "Light ID or name") { |l| options.lights << l }
        opts.on("-gGROUP", "--group=GROUP", "Group ID or name") { |g| options.groups << g }
        opts.on("--all", "All lights and groups TODO") { $stderr.puts "Not Implemented"; exit 1 }
        opts.on("-h", "--help", "Prints this help") { puts opts; exit }
      }
      parser.parse!

      if ARGV.empty?
        puts parser.help
        exit 1
      elsif (bad_paths = ARGV.select { |p| !File.exists? p }).any?
        $stderr.puts "Cannot find #{bad_paths.join ', '}"
        exit 1
      else
        return options, ARGV.map { |path|
          ProgramSrc.new(YAML.load_file(path), path)
        }
      end
    end
  end
end
