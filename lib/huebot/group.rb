module Huebot
  class Group
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
      url "/action"
    end

    def url(path)
      "/groups/#{id}#{path}"
    end
  end
end