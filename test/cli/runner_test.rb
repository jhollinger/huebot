require 'test_helper'
require 'stringio'

class CLIRunnerTest < Minitest::Test
  include TestHelpers

  def setup
    @opts = Huebot::CLI::Options.new([], false)
    @opts.stdin = StringIO.new
    @opts.stdout = StringIO.new
    @opts.stderr = StringIO.new
    @opts.bot_waiter = ->(_) {}

    @client = FauxClient.new
    @lights = [
      Huebot::Light.new(@client, 1, {"name" => "Bookshelf Left"}),
      Huebot::Light.new(@client, 2, {"name" => "Bookshelf Right"}),
    ]
    @groups = [
      Huebot::Group.new(@client, 1, {"name" => "Bookshelf"}),
    ]
  end

  def test_ls
    retval = Huebot::CLI::Runner.ls @lights, @groups, @opts
    assert_io_equals [
      "Lights",
      "  1: Bookshelf Left",
      "  2: Bookshelf Right",
      "Groups",
      "  1: Bookshelf",
    ], @opts.stdout
    assert_io_equals [], @opts.stderr
    assert_equal 0, retval
  end

  def test_run
    @opts.inputs = [Huebot::Group::Input.new("Bookshelf")]
    source = Huebot::Program::Src.new({"transition" => {"devices" => {"inputs" => "$all"}, "state" => {"bri" => 225, "time" => 5}}}, "prog.yaml", 1.0)

    retval = Huebot::CLI::Runner.run [source], @lights, @groups, @opts
    assert_io_equals([], @opts.stdout) { |line| line.sub(/^[^ ]+ /, "") }
    assert_io_equals [], @opts.stderr
    assert_equal 0, retval
  end

  def test_run_with_debug
    @opts.debug = true
    @opts.inputs = [Huebot::Group::Input.new("Bookshelf")]
    source = Huebot::Program::Src.new({"transition" => {"devices" => {"inputs" => "$all"}, "state" => {"bri" => 225, "time" => 5}}}, "prog.yaml", 1.0)

    retval = Huebot::CLI::Runner.run [source], @lights, @groups, @opts
    assert_io_equals([
      %(start {"program":"prog"}),
      %(transition {"devices":["Bookshelf"]}),
      %(set_state {"device":"Bookshelf","state":{"bri":225,"transitiontime":50},"result":null}),
      %(pause {"time":5.0}),
      %(stop {"program":"prog"}),
    ], @opts.stdout) { |line| line.sub(/^[^ ]+ /, "") }
    assert_io_equals [], @opts.stderr
    assert_equal 0, retval
  end

  def test_run_with_errors
    source = Huebot::Program::Src.new({"transition" => {"devices" => {"inputs" => "$all"}, "statez" => {"bri" => 225, "time" => 5}}}, "prog.yaml", 1.0)

    retval = Huebot::CLI::Runner.run [source], @lights, @groups, @opts
    assert_io_equals [], @opts.stdout
    assert_io_equals [
      "Errors:",
      "  1)   prog: 'state' is required in a transition",
      "  2)   prog: Unknown keys in 'transition': statez",
      "Unknown device inputs:",
      "  1) $all",
    ], @opts.stderr
    assert_equal 1, retval
  end

  def test_check
    @opts.inputs = [Huebot::Group::Input.new("Bookshelf")]
    source = Huebot::Program::Src.new({"transition" => {"devices" => {"inputs" => "$all"}, "state" => {"bri" => 225, "time" => 5}}}, "prog.yaml", 1.0)

    retval = Huebot::CLI::Runner.check [source], @lights, @groups, @opts
    assert_io_equals [], @opts.stdout
    assert_io_equals [], @opts.stderr
    assert_equal 0, retval
  end

  def test_check_with_errors
    source = Huebot::Program::Src.new({"transition" => {"devices" => {"inputs" => "$all"}, "statez" => {"bri" => 225, "time" => 5}}}, "prog.yaml", 1.0)

    retval = Huebot::CLI::Runner.check [source], @lights, @groups, @opts
    assert_io_equals [], @opts.stdout
    assert_io_equals [
      "Errors:",
      "  1)   prog: 'state' is required in a transition",
      "  2)   prog: Unknown keys in 'transition': statez",
      "Unknown device inputs:",
      "  1) $all",
    ], @opts.stderr
    assert_equal 1, retval
  end

  def test_get_state
    def @client.get!(path)
      {"state" => {"bri" => 254}}
    end
    @opts.inputs = [Huebot::Group::Input.new("Bookshelf")]

    retval = Huebot::CLI::Runner.get_state @lights, @groups, @opts
    assert_io_equals [
      %(Bookshelf),
      %(  {"bri"=>254}),
    ], @opts.stdout
    assert_io_equals [], @opts.stderr
    assert_equal 0, retval
  end

  def test_set_ip
    Dir.mktmpdir do |dir|
      config_path = File.join(dir, ".huebot")
      config = Huebot::CLI::Config.new config_path

      Huebot::CLI::Runner.set_ip config, "192.168.1.10", @opts
      assert_equal "192.168.1.10", config["ip"]
      config.reload
      assert_equal "192.168.1.10", config["ip"]
    end
  end

  def test_clear_ip
    Dir.mktmpdir do |dir|
      config_path = File.join(dir, ".huebot")
      File.write(config_path, YAML.dump({"ip" => "192.168.1.5"}))
      config = Huebot::CLI::Config.new config_path
      assert_equal "192.168.1.5", config["ip"]

      Huebot::CLI::Runner.clear_ip config, @opts
      config.reload
      assert_nil config["ip"]
    end
  end

  def test_unregister
    Dir.mktmpdir do |dir|
      config_path = File.join(dir, ".huebot")
      config = Huebot::CLI::Config.new config_path
      config["foo"] = "bar"
      config.reload
      assert_equal "bar", config["foo"]

      Huebot::CLI::Runner.unregister config, @opts
      config.reload
      assert_nil config["foo"]
    end
  end
end
