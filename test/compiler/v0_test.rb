require 'test_helper'

class CompilerApiV0Test < Minitest::Test
  def test_foo
    puts "!!!!"
    puts Huebot::Compiler.name
  end
end
