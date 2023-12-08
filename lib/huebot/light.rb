module Huebot
  class Light
    include DeviceState
    attr_reader :client, :id, :name

    def initialize(client, id, attrs)
      @client = client
      @id = id
      @name = attrs.fetch("name")
      @attrs = attrs
    end

    private

    def state_url
      url "/state"
    end

    def url(path)
      "/lights/#{id}#{path}"
    end
  end
end
