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
    Options = Struct.new(:inputs, :read_stdin, :debug, :no_bridge)

    autoload :Helpers, 'huebot/cli/helpers'
    autoload :Runner, 'huebot/cli/runner'
  end
end
