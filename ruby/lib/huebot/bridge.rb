module Huebot
  class Bridge
    def self.connect(client = Client.new)
      error = client.connect
      return nil, error if error
      return new(client)
    end

    def initialize(client)
      @client = client
    end

    def lights
      @client.get!("/lights").map { |(id, attrs)| Light.new(@client, id, attrs) }
    end

    def groups
      @client.get!("/groups").map { |(id, attrs)| Group.new(@client, id, attrs) }
    end
  end
end
