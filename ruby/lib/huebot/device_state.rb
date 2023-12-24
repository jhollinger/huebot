module Huebot
  module DeviceState
    def set_state(state)
      client.put!(state_change_url, state)
    end

    def get_state
      client.get!(url).fetch("state")
    end
  end
end
