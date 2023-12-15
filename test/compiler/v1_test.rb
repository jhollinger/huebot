require 'test_helper'

class CompilerApiV1Test < Minitest::Test
  def test_foo
    puts "!!!!"
    puts Huebot::Compiler.name
  end
end
