require 'hue'

module Huebot
  autoload :Program, 'huebot/program'
  autoload :Compiler, 'huebot/compiler'
  autoload :Bot, 'huebot/bot'
  autoload :VERSION, 'huebot/version'

  #
  # Struct for storing a program's Intermediate Representation and source filepath.
  #
  # @attr ir [Hash]
  # @attr filepath [String]
  #
  ProgramSrc = Struct.new(:ir, :filepath)

  #
  # Struct for specifying a Light input (id or name)
  #
  # @attr val [Integer|String] id or name
  #
  LightInput = Struct.new(:val)

  #
  # Struct for specifying a Gropu input (id or name)
  #
  # @attr val [Integer|String] id or name
  #
  GroupInput = Struct.new(:val)
end
