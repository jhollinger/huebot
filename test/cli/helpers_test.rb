require 'test_helper'
require 'stringio'

class CliHelpersTest < Minitest::Test
  include TestHelpers

  def test_get_cmd
    cmd = Huebot::CLI::Helpers.get_cmd(["run", "foo"])
    assert_equal :run, cmd
  end

  def test_get_args
    args, error = Huebot::CLI::Helpers.get_args(["run", "prog1.yaml", "prog2.json"])
    assert_nil error
    assert_equal ["prog1.yaml", "prog2.json"], args
  end

  def test_min_args
    args, error = Huebot::CLI::Helpers.get_args(["run", "prog1.yaml", "prog2.json"], min: 2)
    assert_nil error
    assert_equal ["prog1.yaml", "prog2.json"], args
  end

  def test_min_args_error
    _args, error = Huebot::CLI::Helpers.get_args(["run", "prog1.yaml"], min: 2)
    assert_equal "Expected at least 2 args, found 1", error
  end

  def test_max_args
    args, error = Huebot::CLI::Helpers.get_args(["run", "prog1.yaml", "prog2.json"], max: 2)
    assert_nil error
    assert_equal ["prog1.yaml", "prog2.json"], args
  end

  def test_max_args_error
    _args, error = Huebot::CLI::Helpers.get_args(["run", "prog0.yaml", "prog2.json"], max: 1)
    assert_equal "Expected no more than 1 args, found 2", error
  end

  def test_min_max_args
    args, error = Huebot::CLI::Helpers.get_args(["run", "prog1.yaml", "prog2.json"], min: 1, max: 2)
    assert_nil error
    assert_equal ["prog1.yaml", "prog2.json"], args
  end

  def test_min_max_args_too_few
    _args, error = Huebot::CLI::Helpers.get_args(["run"], min: 1, max: 2)
    assert_equal "Expected 1-2 args, found 0", error
  end

  def test_min_max_args_too_many
    _args, error = Huebot::CLI::Helpers.get_args(["run", "prog1.yaml", "prog2.json", "prog3.yml"], min: 1, max: 2)
    assert_equal "Expected 1-2 args, found 3", error
  end

  def test_num_args
    args, error = Huebot::CLI::Helpers.get_args(["run", "prog1.yaml", "prog2.json"], num: 2)
    assert_nil error
    assert_equal ["prog1.yaml", "prog2.json"], args
  end

  def test_num_args_error
    _args, error = Huebot::CLI::Helpers.get_args(["run", "prog1.yaml"], num: 2)
    assert_equal "Expected 2 args, found 1", error
  end

  def test_get_input_files
    opts = Huebot::CLI::Helpers.default_options
    opts.stdout = StringIO.new
    opts.stderr = StringIO.new

    Dir.mktmpdir do |dir|
      paths = [File.join(dir, "prog.yaml"), File.join(dir, "prog.yml"), File.join(dir, "prog.json")]
      paths.each { |path|
        to_format = path =~ /json/ ? :to_json : :to_yaml
        File.write path, program_tokens.send(to_format)
      }
      sources = Huebot::CLI::Helpers.get_input! opts, ["run"] + paths
      assert_equal paths, sources.map(&:filepath)
      sources.each { |src| assert_equal program_tokens, src.tokens }
      assert_io_equals [], opts.stdout
      assert_io_equals [], opts.stderr
    end
  end

  def test_get_input_yaml
    opts = Huebot::CLI::Helpers.default_options
    opts.stdin = StringIO.new program_tokens.to_yaml
    opts.stdout = StringIO.new
    opts.stderr = StringIO.new

    sources = Huebot::CLI::Helpers.get_input! opts, ["run"]
    assert_equal ["STDIN"], sources.map(&:filepath)
    sources.each { |src| assert_equal program_tokens, src.tokens }
    assert_io_equals [], opts.stdout
    assert_io_equals [], opts.stderr
  end

  def test_get_input_json
    opts = Huebot::CLI::Helpers.default_options
    opts.stdin = StringIO.new program_tokens.to_json
    opts.stdout = StringIO.new
    opts.stderr = StringIO.new

    sources = Huebot::CLI::Helpers.get_input! opts, ["run"]
    assert_equal ["STDIN"], sources.map(&:filepath)
    sources.each { |src| assert_equal program_tokens, src.tokens }
    assert_io_equals [], opts.stdout
    assert_io_equals [], opts.stderr
  end

  def test_force_get_input
    opts = Huebot::CLI::Helpers.default_options
    opts.read_stdin = true
    stdin = opts.stdin = StringIO.new program_tokens.to_yaml
    opts.stdout = StringIO.new
    opts.stderr = StringIO.new

    def stdin.isatty
      true
    end

    sources = Huebot::CLI::Helpers.get_input! opts, ["run"]
    assert_equal ["STDIN"], sources.map(&:filepath)
    sources.each { |src| assert_equal program_tokens, src.tokens }
    assert_io_equals [
      "Please enter your YAML or JSON Huebot program below, followed by Ctrl+d:",
      "Executing...",
    ], opts.stdout
    assert_io_equals [], opts.stderr
  end

  private

  def program_tokens
    {
      "name" => "Test",
      "serial" => {
        "loop" => {"count" => 3},
        "steps" => [
          {"transition" => {"state" => {"brightness" => 50}, "devices" => {"inputs" => ["$4"]}}},
          {"transition" => {"state" => {"brightness" => 100}, "devices" => {"lights" => ["Office Go"], "groups" => ["Bookshelf"]}, "pause" => 1}},
        ],
      },
    }
  end
end
