module Huebot
  class Light
    #
    # Struct for specifying a Light input (id or name)
    #
    # @attr val [Integer|String] id or name
    #
    Input = Struct.new(:val)

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
