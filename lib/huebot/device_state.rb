module Huebot
  module DeviceState
    def set_state(state)
      client.put!(state_url, state)
    end
  end
end
