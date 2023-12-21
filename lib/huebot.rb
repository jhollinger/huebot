module Huebot
  Error = Class.new(StandardError)

  autoload :Client, 'huebot/client'
  autoload :CLI, 'huebot/cli/cli'
  autoload :Bridge, 'huebot/bridge'
  autoload :DeviceState, 'huebot/device_state'
  autoload :Light, 'huebot/light'
  autoload :Group, 'huebot/group'
  autoload :DeviceMapper, 'huebot/device_mapper'
  autoload :Program, 'huebot/program'
  autoload :Compiler, 'huebot/compiler/compiler'
  autoload :Bot, 'huebot/bot'
  autoload :Logging, 'huebot/logging/logging'
  autoload :VERSION, 'huebot/version'
end
