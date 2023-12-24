module TestHelpers
  def assert_io_equals(expected_lines, io, &transform)
    io.rewind
    lines = io.readlines.map(&:chomp).map(&transform).to_a
    assert_equal expected_lines, lines
  end
end
