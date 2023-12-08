module Huebot
  class Bridge
    def self.connect(config = Huebot::Config.new)
      client = Client.new(config)
      error = client.connect
      return nil, error if error
      return new(client)
    end

    attr_reader :client

    def initialize(client)
      @client = client
    end

    def lights
      client.get!("/lights").map { |(id, attrs)| Light.new(client, id, attrs) }
    end

    def groups
      client.get!("/groups").map { |(id, attrs)| Group.new(client, id, attrs) }
    end
  end
end
