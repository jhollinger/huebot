module Huebot
  module Compiler
    Error = Class.new(Error)

    autoload :ApiV1, 'huebot/compiler/api_v1'
    autoload :ApiV2, 'huebot/compiler/api_v2'

    #
    # Build a huebot program from an intermediate representation (a Hash).
    #
    # @param src [Huebot::Program::Src]
    # @return [Huebot::Program]
    #
    def self.build(src)
      compiler_class =
        case src.api_version
        when 1.0...2.0 then ApiV1
        when 2.0...3.0 then ApiV2
        else raise Error, "Unknown API version '#{src.api_version}'"
        end
      compiler = compiler_class.new(src.api_version)
      compiler.build(src.tokens, src.default_name)
    end
  end
end
