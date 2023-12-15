module Huebot
  class Group
    #
    # Struct for specifying a Group input (id or name)
    #
    # @attr val [Integer|String] id or name
    #
    Input = Struct.new(:val)

    include DeviceState
    attr_reader :client, :id, :name

    def initialize(client, id, attrs)
      @client = client
      @id = id.to_i
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
