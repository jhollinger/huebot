require 'test_helper'
require 'json'

class BotTest < Minitest::Test
  def setup
    client = FauxClient.new
    @device_mapper = Huebot::DeviceMapper.new(
      lights: [
        Huebot::Light.new(client, 5, {"name" => "Bookshelf Left"}),
        Huebot::Light.new(client, 6, {"name" => "Bookshelf Right"}),
        Huebot::Light.new(client, 7, {"name" => "Office Go"}),
      ],
      groups: [
        Huebot::Group.new(client, 8, {"name" => "Bookshelf"}),
        Huebot::Group.new(client, 9, {"name" => "Office"}),
        Huebot::Group.new(client, 10, {"name" => "Downstairs"}),
        Huebot::Group.new(client, 10, {"name" => "Upstairs"}),
      ],
      inputs: [
        Huebot::Group::Input.new("Bookshelf"),
        Huebot::Light::Input.new("Bookshelf Left"),
        Huebot::Light::Input.new("Bookshelf Right"),
        Huebot::Light::Input.new("Office Go"),
      ]
    )
    @compiler = Huebot::Compiler::ApiV1.new(1.1)
    @logger = Huebot::Logging::CollectingLogger.new
    @bot = Huebot::Bot.new(@device_mapper, logger: @logger, waiter: ->(_n) {})
  end

  def test_serial_transitions
    program = @compiler.build({
      "name" => "Test",
      "serial" => {
        "loop" => {"count" => 3},
        "steps" => [
          {"transition" => {"state" => {"brightness" => 50}, "devices" => {"inputs" => ["$4"]}}},
          {"transition" => {"state" => {"brightness" => 100}, "devices" => {"lights" => ["Office Go"], "groups" => ["Bookshelf"]}, "pause" => {"before" => 0.5, "after" => 1}}},
        ],
      },
    })
    assert_equal [], program.errors

    @bot.execute program
    assert_equal [
      "start {\"program\":\"Test\"}",
      "serial {\"loop\":\"counted\"}",
      "transition {\"devices\":[\"Office Go\"]}",
      "set_state {\"device\":\"Office Go\",\"state\":{\"brightness\":50},\"result\":null}",
      "pause {\"time\":0.4}",
      "transition {\"devices\":[\"Office Go\",\"Bookshelf\"]}",
      "pause {\"time\":0.5}",
    ], @logger.events.shift(7).map { |(_ts, event, data)|
      "#{event} #{data.to_json}"
    }

    assert_equal [
      "set_state {\"device\":\"Office Go\",\"state\":{\"brightness\":100},\"result\":null}",
      "pause {\"time\":0.4}",
      "set_state {\"device\":\"Bookshelf\",\"state\":{\"brightness\":100},\"result\":null}",
      "pause {\"time\":0.4}",
    ].sort, @logger.events.shift(4).map { |(_ts, event, data)|
      "#{event} #{data.to_json}"
    }.sort

    assert_equal [
      "pause {\"time\":1}",
      "serial {\"loop\":\"counted\"}",
      "transition {\"devices\":[\"Office Go\"]}",
      "set_state {\"device\":\"Office Go\",\"state\":{\"brightness\":50},\"result\":null}",
      "pause {\"time\":0.4}",
      "transition {\"devices\":[\"Office Go\",\"Bookshelf\"]}",
      "pause {\"time\":0.5}",
    ], @logger.events.shift(7).map { |(_ts, event, data)|
      "#{event} #{data.to_json}"
    }

    assert_equal [
      "set_state {\"device\":\"Office Go\",\"state\":{\"brightness\":100},\"result\":null}",
      "pause {\"time\":0.4}",
      "set_state {\"device\":\"Bookshelf\",\"state\":{\"brightness\":100},\"result\":null}",
      "pause {\"time\":0.4}",
    ].sort, @logger.events.shift(4).map { |(_ts, event, data)|
      "#{event} #{data.to_json}"
    }.sort

    assert_equal [
      "pause {\"time\":1}",
      "serial {\"loop\":\"counted\"}",
      "transition {\"devices\":[\"Office Go\"]}",
      "set_state {\"device\":\"Office Go\",\"state\":{\"brightness\":50},\"result\":null}",
      "pause {\"time\":0.4}",
      "transition {\"devices\":[\"Office Go\",\"Bookshelf\"]}",
      "pause {\"time\":0.5}",
    ], @logger.events.shift(7).map { |(_ts, event, data)|
      "#{event} #{data.to_json}"
    }

    assert_equal [
      "set_state {\"device\":\"Office Go\",\"state\":{\"brightness\":100},\"result\":null}",
      "pause {\"time\":0.4}",
      "set_state {\"device\":\"Bookshelf\",\"state\":{\"brightness\":100},\"result\":null}",
      "pause {\"time\":0.4}",
      "pause {\"time\":1}",
    ].sort, @logger.events.shift(5).map { |(_ts, event, data)|
      "#{event} #{data.to_json}"
    }.sort

    assert_equal [
      "stop {\"program\":\"Test\"}",
    ], @logger.events.map { |(_ts, event, data)|
      "#{event} #{data.to_json}"
    }
  end

  def test_nested_parallel_serial_transitions
    program = @compiler.build({
      "name" => "Test",
      "serial" => {
        "steps" => [
          {"transition" => {"state" => {"brightness" => 100}, "devices" => {"inputs" => "$all"}}},
          {"parallel" => {
            "loop" => {"count" => 2, "pause" => 1},
            "steps" => [
              {"serial" => {
                "steps" => [
                  {"transition" => {"state" => {"brightness" => 200}, "devices" => {"inputs" => ["$1", "$3"]}}},
                  {"transition" => {"state" => {"brightness" => 0}, "devices" => {"inputs" => ["$1", "$3"]}}},
                ],
              }},
              {"serial" => {
                "steps" => [
                  {"transition" => {"state" => {"brightness" => 0}, "devices" => {"inputs" => ["$2", "$4"]}}},
                  {"transition" => {"state" => {"brightness" => 200}, "devices" => {"inputs" => ["$2", "$4"]}}},
                ],
              }},
            ],
          }},
        ],
      },
    })
    assert_equal [], program.errors

    @bot.execute program
    assert_equal [
      "start {\"program\":\"Test\"}",
      "serial {\"loop\":\"counted\"}",
      "transition {\"devices\":[\"Bookshelf\",\"Bookshelf Left\",\"Bookshelf Right\",\"Office Go\"]}",
    ], @logger.events.shift(3).map { |(_ts, event, data)|
      "#{event} #{data.to_json}"
    }

    assert_equal [
      "set_state {\"device\":\"Bookshelf\",\"state\":{\"brightness\":100},\"result\":null}",
      "pause {\"time\":0.4}",
      "set_state {\"device\":\"Bookshelf Left\",\"state\":{\"brightness\":100},\"result\":null}",
      "pause {\"time\":0.4}",
      "set_state {\"device\":\"Bookshelf Right\",\"state\":{\"brightness\":100},\"result\":null}",
      "pause {\"time\":0.4}",
      "set_state {\"device\":\"Office Go\",\"state\":{\"brightness\":100},\"result\":null}",
      "pause {\"time\":0.4}",
    ].sort, @logger.events.shift(8).map { |(_ts, event, data)|
      "#{event} #{data.to_json}"
    }.sort

    assert_equal [
      "parallel {\"loop\":\"counted\"}",
    ], @logger.events.shift(1).map { |(_ts, event, data)|
      "#{event} #{data.to_json}"
    }

    assert_equal [
      "serial {\"loop\":\"counted\"}",
      "transition {\"devices\":[\"Bookshelf\",\"Bookshelf Right\"]}",
      "serial {\"loop\":\"counted\"}",
      "transition {\"devices\":[\"Bookshelf Left\",\"Office Go\"]}",
      "set_state {\"device\":\"Office Go\",\"state\":{\"brightness\":0},\"result\":null}",
      "pause {\"time\":0.4}",
      "set_state {\"device\":\"Bookshelf Right\",\"state\":{\"brightness\":200},\"result\":null}",
      "pause {\"time\":0.4}",
      "set_state {\"device\":\"Bookshelf\",\"state\":{\"brightness\":200},\"result\":null}",
      "pause {\"time\":0.4}",
      "set_state {\"device\":\"Bookshelf Left\",\"state\":{\"brightness\":0},\"result\":null}",
      "pause {\"time\":0.4}",
      "transition {\"devices\":[\"Bookshelf Left\",\"Office Go\"]}",
      "set_state {\"device\":\"Bookshelf Left\",\"state\":{\"brightness\":200},\"result\":null}",
      "pause {\"time\":0.4}",
      "set_state {\"device\":\"Office Go\",\"state\":{\"brightness\":200},\"result\":null}",
      "pause {\"time\":0.4}",
      "transition {\"devices\":[\"Bookshelf\",\"Bookshelf Right\"]}",
      "set_state {\"device\":\"Bookshelf\",\"state\":{\"brightness\":0},\"result\":null}",
      "pause {\"time\":0.4}",
      "set_state {\"device\":\"Bookshelf Right\",\"state\":{\"brightness\":0},\"result\":null}",
      "pause {\"time\":0.4}",
      "pause {\"time\":1}",
    ].sort, @logger.events.shift(23).map { |(_ts, event, data)|
      "#{event} #{data.to_json}"
    }.sort

    assert_equal [
      "parallel {\"loop\":\"counted\"}",
    ], @logger.events.shift(1).map { |(_ts, event, data)|
      "#{event} #{data.to_json}"
    }

    assert_equal [
      "serial {\"loop\":\"counted\"}",
      "transition {\"devices\":[\"Bookshelf\",\"Bookshelf Right\"]}",
      "serial {\"loop\":\"counted\"}",
      "transition {\"devices\":[\"Bookshelf Left\",\"Office Go\"]}",
      "set_state {\"device\":\"Bookshelf\",\"state\":{\"brightness\":200},\"result\":null}",
      "pause {\"time\":0.4}",
      "set_state {\"device\":\"Bookshelf Right\",\"state\":{\"brightness\":200},\"result\":null}",
      "pause {\"time\":0.4}",
      "set_state {\"device\":\"Bookshelf Left\",\"state\":{\"brightness\":0},\"result\":null}",
      "pause {\"time\":0.4}",
      "set_state {\"device\":\"Office Go\",\"state\":{\"brightness\":0},\"result\":null}",
      "pause {\"time\":0.4}",
      "transition {\"devices\":[\"Bookshelf\",\"Bookshelf Right\"]}",
      "transition {\"devices\":[\"Bookshelf Left\",\"Office Go\"]}",
      "set_state {\"device\":\"Bookshelf\",\"state\":{\"brightness\":0},\"result\":null}",
      "pause {\"time\":0.4}",
      "set_state {\"device\":\"Bookshelf Right\",\"state\":{\"brightness\":0},\"result\":null}",
      "pause {\"time\":0.4}",
      "set_state {\"device\":\"Bookshelf Left\",\"state\":{\"brightness\":200},\"result\":null}",
      "pause {\"time\":0.4}",
      "set_state {\"device\":\"Office Go\",\"state\":{\"brightness\":200},\"result\":null}",
      "pause {\"time\":0.4}",
      "pause {\"time\":1}",
    ].sort, @logger.events.shift(23).map { |(_ts, event, data)|
      "#{event} #{data.to_json}"
    }.sort

    assert_equal [
      "stop {\"program\":\"Test\"}",
    ], @logger.events.map { |(_ts, event, data)|
      "#{event} #{data.to_json}"
    }
  end
end
