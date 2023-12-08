require 'fileutils'
require 'yaml'

module Huebot
  class Config
    def initialize(path = "~/.config/huebot")
      @path = File.expand_path(path)
      @dir = File.dirname(@path)
      @dir_exists = File.exist? @dir
      @config = File.exist?(@path) ? YAML.load_file(@path) : {}
    end

    def [](attr)
      @config[attr.to_s]
    end

    def []=(attr, val)
      if val.nil?
        @config.delete(attr.to_s)
      else
        @config[attr.to_s] = val
      end
      write
    end

    def clear
      @config.clear
      write
    end

    private

    def write
      unless @dir_exists
        FileUtils.mkdir_p @dir
        @dir_exists = true
      end
      File.write(@path, YAML.dump(@config))
    end
  end
end
