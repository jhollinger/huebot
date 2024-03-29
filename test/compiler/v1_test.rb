require 'test_helper'
require 'yaml'

class CompilerApiV1Test < Minitest::Test
  def test_from_source
    src = Huebot::Program::Src.new({
      "name" => "Test",
      "transition" => {
        "devices" => {"inputs" => "$all"},
        "state" => {"bri" => 250},
      },
    }, "STDIN", 1.0)
    program = Huebot::Compiler.build(src)
    assert_equal Huebot::Program, program.class
    assert_equal Huebot::Program::AST::Node, program.data.class

    assert_equal "Test", program.name
    assert_equal 1.0, program.api_version
    assert_equal [], program.errors
    assert_equal [], program.warnings
    assert_equal Huebot::Program::AST::Transition, program.data.instruction.class
    assert_equal({"bri" => 250}, program.data.instruction.state)
    assert_equal [Huebot::Program::AST::DeviceRef], program.data.instruction.devices.map(&:class)
    assert_equal [], program.data.children
  end

  def test_program_metadata
    compiler = Huebot::Compiler::ApiV1.new(1.0)
    program = compiler.build({
      "name" => "Test",
      "transition" => {
        "devices" => {"inputs" => "$all"},
        "state" => {"bri" => 250},
        "pause" => 0.5,
      },
    })

    assert_equal Huebot::Program, program.class
    assert_equal Huebot::Program::AST::Node, program.data.class

    assert_equal "Test", program.name
    assert_equal 1.0, program.api_version
  end

  def test_transition
    compiler = Huebot::Compiler::ApiV1.new(1.0)
    program = compiler.build({
      "name" => "Test",
      "transition" => {
        "devices" => {"inputs" => "$all"},
        "state" => {"bri" => 250},
      },
    })

    assert_equal [], program.errors
    assert_equal [], program.warnings
    assert_equal Huebot::Program::AST::Transition, program.data.instruction.class
    assert_equal({"bri" => 250}, program.data.instruction.state)
    assert program.data.instruction.wait
    assert_equal [Huebot::Program::AST::DeviceRef], program.data.instruction.devices.map(&:class)
    assert_equal [], program.data.children
  end

  def test_transition_1_1
    compiler = Huebot::Compiler::ApiV1.new(1.1)
    program = compiler.build({
      "name" => "Test",
      "transition" => {
        "devices" => {"inputs" => "$all"},
        "state" => {"bri" => 250},
      },
    })

    assert_equal [], program.errors
    assert_equal [], program.warnings
    assert_equal Huebot::Program::AST::Transition, program.data.instruction.class
    assert_equal({"bri" => 250}, program.data.instruction.state)
    assert program.data.instruction.wait
    assert_equal [Huebot::Program::AST::DeviceRef], program.data.instruction.devices.map(&:class)
    assert_equal [], program.data.children
  end

  def test_transition_1_1_with_wait_true
    compiler = Huebot::Compiler::ApiV1.new(1.1)
    program = compiler.build({
      "name" => "Test",
      "transition" => {
        "devices" => {"inputs" => "$all"},
        "state" => {"bri" => 250},
        "wait" => true,
      },
    })

    assert_equal [], program.errors
    assert_equal [], program.warnings
    assert_equal Huebot::Program::AST::Transition, program.data.instruction.class
    assert_equal({"bri" => 250}, program.data.instruction.state)
    assert program.data.instruction.wait
    assert_equal [Huebot::Program::AST::DeviceRef], program.data.instruction.devices.map(&:class)
    assert_equal [], program.data.children
  end

  def test_transition_1_1_with_wait_false
    compiler = Huebot::Compiler::ApiV1.new(1.1)
    program = compiler.build({
      "name" => "Test",
      "transition" => {
        "devices" => {"inputs" => "$all"},
        "state" => {"bri" => 250},
        "wait" => false,
      },
    })

    assert_equal [], program.errors
    assert_equal [], program.warnings
    assert_equal Huebot::Program::AST::Transition, program.data.instruction.class
    assert_equal({"bri" => 250}, program.data.instruction.state)
    refute program.data.instruction.wait
    assert_equal [Huebot::Program::AST::DeviceRef], program.data.instruction.devices.map(&:class)
    assert_equal [], program.data.children
  end

  def test_transition_with_sleep
    compiler = Huebot::Compiler::ApiV1.new(1.0)
    program = compiler.build({
      "name" => "Test",
      "transition" => {
        "devices" => {"inputs" => "$all"},
        "state" => {"bri" => 250},
        "pause" => 0.5,
      },
    })

    assert_equal [], program.errors
    assert_equal [], program.warnings
    assert_equal Huebot::Program::AST::Transition, program.data.instruction.class
    assert_equal({"bri" => 250}, program.data.instruction.state)
    assert_equal [Huebot::Program::AST::DeviceRef], program.data.instruction.devices.map(&:class)
    assert_equal Huebot::Program::AST::Num.new(0.5), program.data.instruction.pause.post
  end

  def test_transition_with_1_1_pause
    compiler = Huebot::Compiler::ApiV1.new(1.1)
    program = compiler.build({
      "name" => "Test",
      "transition" => {
        "devices" => {"inputs" => "$all"},
        "state" => {"bri" => 250},
        "pause" => {
          "before" => 1.5,
          "after" => 0.5,
        }
      },
    })

    assert_equal [], program.errors
    assert_equal [], program.warnings
    assert_equal Huebot::Program::AST::Transition, program.data.instruction.class
    assert_equal({"bri" => 250}, program.data.instruction.state)
    assert_equal [Huebot::Program::AST::DeviceRef], program.data.instruction.devices.map(&:class)
    assert_equal Huebot::Program::AST::Num.new(1.5), program.data.instruction.pause.pre
    assert_equal Huebot::Program::AST::Num.new(0.5), program.data.instruction.pause.post
  end

  def test_device_refs
    compiler = Huebot::Compiler::ApiV1.new(1.0)
    program = compiler.build({
      "name" => "Test",
      "serial" => {
        "steps" => [
          {"transition" => {"state" => {}, "devices" => {"inputs" => "$all"}}},
          {"transition" => {"state" => {}, "devices" => {"inputs" => ["$2", "$3"]}}},
          {"parallel" => {
            "steps" => [
              {"transition" => {"state" => {}, "devices" => {"inputs" => ["$4"]}}},
              {"transition" => {"state" => {}, "devices" => {"lights" => ["Foo"], "groups" => ["Bar"]}}},
              {"transition" => {"state" => {}, "devices" => {"inputs" => ["$1", "$5"]}}},
            ]
          }}
        ]
      },
    })

    assert_equal [], program.errors
    assert_equal [], program.warnings
    assert_equal [:all, 1, 2, 3, 4, 5].map(&:to_s).sort, program.device_refs.map(&:to_s).sort
  end

  def test_light_names
    compiler = Huebot::Compiler::ApiV1.new(1.0)
    program = compiler.build({
      "name" => "Test",
      "serial" => {
        "steps" => [
          {"transition" => {"state" => {}, "devices" => {"inputs" => "$all", "lights" => ["LR1"]}}},
          {"transition" => {"state" => {}, "devices" => {"lights" => ["LR2", "LR3"]}}},
          {"parallel" => {
            "steps" => [
              {"transition" => {"state" => {}, "devices" => {"inputs" => ["$4"]}}},
              {"transition" => {"state" => {}, "devices" => {"lights" => ["Foo"], "groups" => ["Bar"]}}},
              {"transition" => {"state" => {}, "devices" => {"inputs" => ["$1", "$5"]}}},
            ]
          }}
        ]
      },
    })

    assert_equal [], program.errors
    assert_equal [], program.warnings
    assert_equal ["Foo", "LR1", "LR2", "LR3"].sort, program.light_names.sort
  end

  def test_group_names
    compiler = Huebot::Compiler::ApiV1.new(1.0)
    program = compiler.build({
      "name" => "Test",
      "serial" => {
        "steps" => [
          {"transition" => {"state" => {}, "devices" => {"inputs" => "$all", "groups" => ["Upstairs"]}}},
          {"transition" => {"state" => {}, "devices" => {"groups" => ["Downstairs", "Outside"]}}},
          {"parallel" => {
            "steps" => [
              {"transition" => {"state" => {}, "devices" => {"inputs" => ["$4"]}}},
              {"transition" => {"state" => {}, "devices" => {"lights" => ["Foo"], "groups" => ["Bar"]}}},
              {"transition" => {"state" => {}, "devices" => {"inputs" => ["$1", "$5"]}}},
            ]
          }}
        ]
      },
    })

    assert_equal [], program.errors
    assert_equal [], program.warnings
    assert_equal ["Bar", "Downstairs", "Outside", "Upstairs"].sort, program.group_names.sort
  end

  def test_build_serial_transitions
    compiler = Huebot::Compiler::ApiV1.new(1.0)
    program = compiler.build({
      "name" => "Test",
      "serial" => {
        "devices" => {"inputs" => "$all"},
        "steps" => [
          {"transition" => {"state" => {"brightness" => 50}, "devices" => {"inputs" => ["$4"]}}},
          {"transition" => {"state" => {"brightness" => 100}, "devices" => {"lights" => ["Foo"], "groups" => ["Bar"]}, "pause" => 20}},
          {"transition" => {"state" => {"brightness" => 200}}},
        ],
        "pause" => 10,
      },
    })
    assert_equal [], program.errors
    assert_equal [], program.warnings

    p = program.data
    assert_equal Huebot::Program::AST::SerialControl, p.instruction.class
    assert_equal Huebot::Program::AST::Num.new(10), p.instruction.pause.post
    assert_equal Huebot::Program::AST::Num.new(1), p.instruction.loop.n
    assert_equal 3, p.children.size
    c1, c2, c3 = p.children

    assert_equal Huebot::Program::AST::Transition, c1.instruction.class
    assert_equal({"brightness" => 50}, c1.instruction.state)
    assert_equal([Huebot::Program::AST::DeviceRef.new(4)], c1.instruction.devices)
    assert_nil c1.instruction.pause

    assert_equal Huebot::Program::AST::Transition, c2.instruction.class
    assert_equal({"brightness" => 100}, c2.instruction.state)
    assert_equal([
      Huebot::Program::AST::Light.new("Foo"),
      Huebot::Program::AST::Group.new("Bar"),
    ], c2.instruction.devices)
    assert_equal Huebot::Program::AST::Num.new(20), c2.instruction.pause.post

    assert_equal Huebot::Program::AST::Transition, c3.instruction.class
    assert_equal({"brightness" => 200}, c3.instruction.state)
    assert_equal([Huebot::Program::AST::DeviceRef.new(:all)], c3.instruction.devices)
    assert_nil c3.instruction.pause
  end

  def test_build_parallel_transitions
    compiler = Huebot::Compiler::ApiV1.new(1.0)
    program = compiler.build({
      "name" => "Test",
      "parallel" => {
        "devices" => {"inputs" => "$all"},
        "steps" => [
          {"transition" => {"state" => {"brightness" => 50}, "devices" => {"inputs" => ["$4"]}}},
          {"transition" => {"state" => {"brightness" => 100}, "devices" => {"lights" => ["Foo"], "groups" => ["Bar"]}, "pause" => 20}},
          {"transition" => {"state" => {"brightness" => 200}}},
        ],
        "pause" => 10,
      },
    })
    assert_equal [], program.errors
    assert_equal [], program.warnings

    p = program.data
    assert_equal Huebot::Program::AST::ParallelControl, p.instruction.class
    assert_equal Huebot::Program::AST::Num.new(10), p.instruction.pause.post
    assert_equal Huebot::Program::AST::Num.new(1), p.instruction.loop.n
    assert_equal 3, p.children.size
    c1, c2, c3 = p.children

    assert_equal Huebot::Program::AST::Transition, c1.instruction.class
    assert_equal({"brightness" => 50}, c1.instruction.state)
    assert_equal([Huebot::Program::AST::DeviceRef.new(4)], c1.instruction.devices)
    assert_nil c1.instruction.pause

    assert_equal Huebot::Program::AST::Transition, c2.instruction.class
    assert_equal({"brightness" => 100}, c2.instruction.state)
    assert_equal([
      Huebot::Program::AST::Light.new("Foo"),
      Huebot::Program::AST::Group.new("Bar"),
    ], c2.instruction.devices)
    assert_equal Huebot::Program::AST::Num.new(20), c2.instruction.pause.post

    assert_equal Huebot::Program::AST::Transition, c3.instruction.class
    assert_equal({"brightness" => 200}, c3.instruction.state)
    assert_equal([Huebot::Program::AST::DeviceRef.new(:all)], c3.instruction.devices)
    assert_nil c3.instruction.pause
  end

  def test_build_serial_transitions_with_count_loop
    compiler = Huebot::Compiler::ApiV1.new(1.0)
    program = compiler.build({
      "name" => "Test",
      "serial" => {
        "devices" => {"inputs" => "$all"},
        "steps" => [
          {"transition" => {"state" => {"brightness" => 50}, "devices" => {"inputs" => ["$4"]}}},
          {"transition" => {"state" => {"brightness" => 100}, "devices" => {"lights" => ["Foo"], "groups" => ["Bar"]}, "pause" => 20}},
          {"transition" => {"state" => {"brightness" => 200}}},
        ],
        "pause" => 10,
        "loop" => {"count" => 5},
      },
    })
    assert_equal [], program.errors
    assert_equal [], program.warnings

    p = program.data
    assert_equal Huebot::Program::AST::SerialControl, p.instruction.class
    assert_equal Huebot::Program::AST::Num.new(10), p.instruction.pause.post
    assert_equal Huebot::Program::AST::Num.new(5), p.instruction.loop.n
    assert_equal 3, p.children.size
  end

  def test_build_serial_transitions_with_timer_loop
    compiler = Huebot::Compiler::ApiV1.new(1.0)
    program = compiler.build({
      "name" => "Test",
      "serial" => {
        "devices" => {"inputs" => "$all"},
        "steps" => [
          {"transition" => {"state" => {"brightness" => 50}, "devices" => {"inputs" => ["$4"]}}},
          {"transition" => {"state" => {"brightness" => 100}, "devices" => {"lights" => ["Foo"], "groups" => ["Bar"]}, "pause" => 20}},
          {"transition" => {"state" => {"brightness" => 200}}},
        ],
        "pause" => 10,
        "loop" => {"timer" => {"hours" => 1, "minutes" => 20}},
      },
    })
    assert_equal [], program.errors
    assert_equal [], program.warnings

    p = program.data
    assert_equal Huebot::Program::AST::SerialControl, p.instruction.class
    assert_equal Huebot::Program::AST::Num.new(10), p.instruction.pause.post
    assert_equal 1, p.instruction.loop.hours
    assert_equal 20, p.instruction.loop.minutes
    assert_equal 3, p.children.size
  end

  def test_build_serial_transitions_with_deadline_loop
    compiler = Huebot::Compiler::ApiV1.new(1.0)
    program = compiler.build({
      "name" => "Test",
      "serial" => {
        "devices" => {"inputs" => "$all"},
        "steps" => [
          {"transition" => {"state" => {"brightness" => 50}, "devices" => {"inputs" => ["$4"]}}},
          {"transition" => {"state" => {"brightness" => 100}, "devices" => {"lights" => ["Foo"], "groups" => ["Bar"]}, "pause" => 20}},
          {"transition" => {"state" => {"brightness" => 200}}},
        ],
        "pause" => 10,
        "loop" => {"until" => {"date" => "2023-12-17", "time" => "17:05"}},
      },
    })
    assert_equal [], program.errors
    assert_equal 1, program.warnings.size

    p = program.data
    assert_equal Huebot::Program::AST::SerialControl, p.instruction.class
    assert_equal Huebot::Program::AST::Num.new(10), p.instruction.pause.post
    assert_equal 2023, p.instruction.loop.stop_time.year
    assert_equal 12, p.instruction.loop.stop_time.month
    assert_equal 17, p.instruction.loop.stop_time.day
    assert_equal 17, p.instruction.loop.stop_time.hour
    assert_equal 5, p.instruction.loop.stop_time.min
    assert_equal 0, p.instruction.loop.stop_time.sec
    assert_equal 3, p.children.size
  end

  def test_build_parallel_transitions_with_count_loop
    compiler = Huebot::Compiler::ApiV1.new(1.0)
    program = compiler.build({
      "name" => "Test",
      "parallel" => {
        "devices" => {"inputs" => "$all"},
        "steps" => [
          {"transition" => {"state" => {"brightness" => 50}, "devices" => {"inputs" => ["$4"]}}},
          {"transition" => {"state" => {"brightness" => 100}, "devices" => {"lights" => ["Foo"], "groups" => ["Bar"]}, "pause" => 20}},
          {"transition" => {"state" => {"brightness" => 200}}},
        ],
        "pause" => 10,
        "loop" => {"count" => 5},
      },
    })
    assert_equal [], program.errors
    assert_equal [], program.warnings

    p = program.data
    assert_equal Huebot::Program::AST::ParallelControl, p.instruction.class
    assert_equal Huebot::Program::AST::Num.new(10), p.instruction.pause.post
    assert_equal Huebot::Program::AST::Num.new(5), p.instruction.loop.n
    assert_equal 3, p.children.size
  end

  def test_build_parallel_transitions_with_timer_loop
    compiler = Huebot::Compiler::ApiV1.new(1.0)
    program = compiler.build({
      "name" => "Test",
      "parallel" => {
        "devices" => {"inputs" => "$all"},
        "steps" => [
          {"transition" => {"state" => {"brightness" => 50}, "devices" => {"inputs" => ["$4"]}}},
          {"transition" => {"state" => {"brightness" => 100}, "devices" => {"lights" => ["Foo"], "groups" => ["Bar"]}, "pause" => 20}},
          {"transition" => {"state" => {"brightness" => 200}}},
        ],
        "pause" => 10,
        "loop" => {"timer" => {"hours" => 1, "minutes" => 20}},
      },
    })
    assert_equal [], program.errors
    assert_equal [], program.warnings

    p = program.data
    assert_equal Huebot::Program::AST::ParallelControl, p.instruction.class
    assert_equal Huebot::Program::AST::Num.new(10), p.instruction.pause.post
    assert_equal 1, p.instruction.loop.hours
    assert_equal 20, p.instruction.loop.minutes
    assert_equal 3, p.children.size
  end

  def test_crazy_nested_program
    compiler = Huebot::Compiler::ApiV1.new(1.0)
    program = compiler.build({
      "name" => "Test",
      "serial" => {
        "loop" => {"infinite" => true},
        "devices" => {"inputs" => "$all"},
        "steps" => [
          {"transition" => {"state" => {"brightness" => 50}, "devices" => {"inputs" => ["$4"]}}},
          {"transition" => {"state" => {"brightness" => 100}, "devices" => {"lights" => ["Foo"], "groups" => ["Bar"]}, "pause" => 20}},
          {
            "parallel" => {
              "steps" => [
                {
                  "serial" => {
                    "devices" => {"groups" => ["Upstairs"]},
                    "steps" => [
                      {"transition" => {"state" => {"brightness" => 50}}},
                      {"transition" => {"state" => {"brightness" => 100}}},
                      {"transition" => {"state" => {"brightness" => 200}}},
                    ]
                  }
                },
                {
                  "serial" => {
                    "devices" => {"groups" => ["Downstairs"]},
                    "steps" => [
                      {"transition" => {"state" => {"brightness" => 200}}},
                      {"transition" => {"state" => {"brightness" => 100}}},
                      {"transition" => {"state" => {"brightness" => 50}}},
                    ]
                  }
                },
              ],
              "loop" => {"timer" => {"hours" => 8}},
              "pause" => 30,
            },
          }
        ]
      },
    })
    assert_equal [], program.errors
    assert_equal [], program.warnings

    p = program.data
    assert_equal Huebot::Program::AST::SerialControl, p.instruction.class
    assert_equal Huebot::Program::AST::InfiniteLoop, p.instruction.loop.class
    assert_equal 3, p.children.size
    c1, c2, c3 = p.children

    assert_equal Huebot::Program::AST::Transition, c1.instruction.class
    assert_equal({"brightness" => 50}, c1.instruction.state)
    assert_equal([Huebot::Program::AST::DeviceRef.new(4)], c1.instruction.devices)
    assert_nil c1.instruction.pause

    assert_equal Huebot::Program::AST::Transition, c2.instruction.class
    assert_equal({"brightness" => 100}, c2.instruction.state)
    assert_equal([
      Huebot::Program::AST::Light.new("Foo"),
      Huebot::Program::AST::Group.new("Bar"),
    ], c2.instruction.devices)
    assert_equal Huebot::Program::AST::Num.new(20), c2.instruction.pause.post

    assert_equal Huebot::Program::AST::ParallelControl, c3.instruction.class
    assert_equal 8, c3.instruction.loop.hours
    assert_equal Huebot::Program::AST::Num.new(30), c3.instruction.pause.post
    assert_equal 2, c3.children.size

    assert_equal Huebot::Program::AST::SerialControl, c3.children[0].instruction.class
    assert_equal 3, c3.children[0].children.size
    assert_equal [Huebot::Program::AST::Transition], c3.children[0].children.map { |c| c.instruction.class }.uniq
    assert_equal({"brightness" => 50}, c3.children[0].children[0].instruction.state)
    assert_equal [Huebot::Program::AST::Group.new("Upstairs")], c3.children[0].children[0].instruction.devices

    assert_equal Huebot::Program::AST::SerialControl, c3.children[1].instruction.class
    assert_equal 3, c3.children[1].children.size
    assert_equal [Huebot::Program::AST::Transition], c3.children[1].children.map { |c| c.instruction.class }.uniq
    assert_equal({"brightness" => 200}, c3.children[1].children[0].instruction.state)
    assert_equal [Huebot::Program::AST::Group.new("Downstairs")], c3.children[1].children[0].instruction.devices
  end

  # YAML is stupid and converts the "on" key to true
  def test_state_yaml_on_key_fix
    src = Huebot::Program::Src.new(::YAML.load("
      name: Test
      transition:
        devices:
          inputs: $all
        state:
          on: true
          bri: 254
    "), "STDIN", 1.0)
    program = Huebot::Compiler.build(src)
    assert_equal [], program.errors
    assert_equal [], program.warnings

    assert_equal({"on" => true, "bri" => 254}, program.data.instruction.state)
  end

  def test_state_time
    src = Huebot::Program::Src.new({
      "name" => "Test",
      "transition" => {
        "devices" => {"inputs" => "$all"},
        "state" => {"bri" => 200, "time" => 3.5},
      },
    }, "STDIN", 1.0)
    program = Huebot::Compiler.build(src)
    assert_equal [], program.errors
    assert_equal [], program.warnings

    assert_equal(35, program.data.instruction.state["transitiontime"])
  end

  def test_state_kelvin_ct
    src = Huebot::Program::Src.new({
      "name" => "Test",
      "transition" => {
        "devices" => {"inputs" => "$all"},
        "state" => {"ctk" => 5000},
      },
    }, "STDIN", 1.0)
    program = Huebot::Compiler.build(src)
    assert_equal [], program.errors
    assert_equal [], program.warnings

    assert_equal({"ct" => 200}, program.data.instruction.state)
  end

  def test_state_kelvin_ct_range_error
    min_k = Huebot::Compiler::ApiV1::MIN_KELVIN
    max_k = Huebot::Compiler::ApiV1::MAX_KELVIN
    src = Huebot::Program::Src.new({
      "name" => "Test",
      "transition" => {
        "devices" => {"inputs" => "$all"},
        "state" => {"ctk" => max_k + 1},
      },
    }, "STDIN", 1.0)
    program = Huebot::Compiler.build(src)
    assert_equal ["'transition.state.ctk' must be an integer between #{min_k} and #{max_k}"], program.errors
    assert_equal [], program.warnings
  end

  def test_state_percent_bri
    src = Huebot::Program::Src.new({
      "name" => "Test",
      "transition" => {
        "devices" => {"inputs" => "$all"},
        "state" => {"bri" => "50%"},
      },
    }, "STDIN", 1.0)
    program = Huebot::Compiler.build(src)
    assert_equal [], program.errors
    assert_equal [], program.warnings

    assert_equal({"bri" => 127}, program.data.instruction.state)
  end

  def test_state_percent_bri_range_error
    src = Huebot::Program::Src.new({
      "name" => "Test",
      "transition" => {
        "devices" => {"inputs" => "$all"},
        "state" => {"bri" => "150%"},
      },
    }, "STDIN", 1.0)
    program = Huebot::Compiler.build(src)
    assert_equal ["'transition.state.bri' must be an integer or a percent between 0% and 100%"], program.errors
    assert_equal [], program.warnings
  end

  def test_random_loop
    src = Huebot::Program::Src.new({
      "name" => "Test",
      "serial" => {
        "loop" => {
          "random" => {"min" => 1, "max" => 10},
        },
        "steps" => [
          "transition" => {
            "devices" => {"inputs" => "$all"},
            "state" => {"bri" => "100%"},
          },
        ],
      },
    }, "STDIN", 1.2)
    program = Huebot::Compiler.build(src)
    assert_equal [], program.errors
    assert_equal [], program.warnings

    assert_equal Huebot::Program::AST::RandomNum, program.data.instruction.loop.n.class
    assert_equal 1, program.data.instruction.loop.n.min
    assert_equal 10, program.data.instruction.loop.n.max
  end

  def test_random_pause
    src = Huebot::Program::Src.new({
      "name" => "Test",
      "transition" => {
        "devices" => {"inputs" => "$all"},
        "state" => {"bri" => "100%"},
        "pause" => {
          "after" => {
            "random" => {"min" => 1, "max" => 10},
          }
        }
      },
    }, "STDIN", 1.2)
    program = Huebot::Compiler.build(src)
    assert_equal [], program.errors
    assert_equal [], program.warnings

    assert_equal Huebot::Program::AST::RandomNum, program.data.instruction.pause.post.class
    assert_equal 1, program.data.instruction.pause.post.min
    assert_equal 10, program.data.instruction.pause.post.max
  end
end
