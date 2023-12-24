require 'uri'
require 'net/http'
require 'json'

module Huebot
  class Client
    DISCOVERY_URI = URI(ENV["HUE_DISCOVERY_API"] || "https://discovery.meethue.com/")
    Bridge = Struct.new(:id, :ip)
    Error = Class.new(Error)

    attr_reader :config

    def initialize(config = Huebot::CLI::Config.new)
      @config = config
      @ip = config["ip"] # NOTE will usually be null
      @username = nil
    end

    def connect
      if config["ip"]
        @ip = config["ip"]
      elsif config["id"]
        @ip = bridges.detect { |b| b.id == id }&.ip
        return "Unable to find Hue Bridge '#{config["id"]}' on your network" if @ip.nil?
      else
        bridge = bridges.first
        return "Unable to find a Hue Bridge on your network" if bridge.nil?
        config["id"] = bridge.id
        @ip = bridge.ip
      end

      if config["username"]
        if valid_username? config["username"]
          @username = config["username"]
        else
          return "Invalid Hue Bridge username '#{config["username"]}'"
        end
      else
        username, error = register
        return error if error
        config["username"] = @username = username
      end
      nil
    end

    def get!(path)
      resp, error = get path
      raise Error, error if error
      resp
    end

    def get(path)
      url = "http://#{@ip}/api"
      url << "/#{@username}" if @username
      url << path
      req = Net::HTTP::Get.new(URI(url))
      req_json req
    end

    def post!(path, body)
      resp, error = post path, body
      raise Error, error if error
      resp
    end

    def post(path, body)
      url = "http://#{@ip}/api"
      url << "/#{@username}" if @username
      url << path
      req = Net::HTTP::Post.new(URI(url))
      req["Content-Type"] = "application/json"
      req.body = body.to_json
      req_json req
    end

    def put!(path, body)
      resp, error = put path, body
      raise Error, error if error
      resp
    end

    def put(path, body)
      url = "http://#{@ip}/api"
      url << "/#{@username}" if @username
      url << path
      req = Net::HTTP::Put.new(URI(url))
      req["Content-Type"] = "application/json"
      req.body = body.to_json
      req_json req
    end

    def req_json(req)
      resp = Net::HTTP.start req.uri.host, req.uri.port, {use_ssl: false} do |http|
        http.request req
      end
      case resp.code.to_i
      when 200..201
        data = JSON.parse(resp.body)
        if data[0] and (error = data[0]["error"])
          return nil, error.fetch("description")
        else
          return data, nil
        end
      else
        raise Error, "Unexpected response from Bridge (#{resp.code}): #{resp.body}"
      end
    end

    def bridges
      req = Net::HTTP::Get.new(DISCOVERY_URI)
      resp = Net::HTTP.start req.uri.host, req.uri.port, {use_ssl: true} do |http|
        http.request req
      end
      JSON.parse(resp.body).map { |x|
        Bridge.new(x.fetch("id"), x.fetch("internalipaddress"))
      }
    end

    private

    def valid_username?(username)
      _resp, error = get("/#{username}")
      !error
    end

    def register
      resp, error = post "/", {"devicetype": "huebot"}
      return nil, error if error
      resp[0].fetch("success").fetch("username")
    end
  end
end
