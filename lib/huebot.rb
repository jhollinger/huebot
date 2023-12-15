module Huebot
  Error = Class.new(StandardError)

  autoload :Config, 'huebot/config'
  autoload :Client, 'huebot/client'
  autoload :CLI, 'huebot/cli'
  autoload :Bridge, 'huebot/bridge'
  autoload :DeviceState, 'huebot/device_state'
  autoload :Light, 'huebot/light'
  autoload :Group, 'huebot/group'
  autoload :DeviceMapper, 'huebot/device_mapper'
  autoload :Program, 'huebot/program'
  autoload :Compiler, 'huebot/compiler'
  autoload :Bot, 'huebot/bot'
  autoload :VERSION, 'huebot/version'
end
