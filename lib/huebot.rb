module Huebot
  autoload :Config, 'huebot/config'
  autoload :Client, 'huebot/client'
  autoload :Bridge, 'huebot/bridge'
  autoload :DeviceState, 'huebot/device_state'
  autoload :Light, 'huebot/light'
  autoload :Group, 'huebot/group'
  autoload :DeviceMapper, 'huebot/device_mapper'
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
  # Struct for specifying a Group input (id or name)
  #
  # @attr val [Integer|String] id or name
  #
  GroupInput = Struct.new(:val)
end
