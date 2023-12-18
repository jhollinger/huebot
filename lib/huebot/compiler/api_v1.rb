require 'date'
require 'time'

module Huebot
  module Compiler
    class ApiV1
      DEVICE_REF = /\A\$([1-9][0-9]*)\Z/.freeze
      TRANSITION_KEYS = ["transition"].freeze
      SERIAL_KEYS = ["serial"].freeze
      PARALLEL_KEYS = ["parallel"].freeze
      INFINITE_KEYS = ["infinite"].freeze
      COUNT_KEYS = ["count"].freeze
      TIMER_KEYS = ["timer"].freeze
      DEADLINE_KEYS = ["until"].freeze
      HHMM = /\A[0-9]{2}:[0-9]{2}\Z/.freeze

      def initialize(api_version)
        @api_version = api_version
      end

      # @return [Huebot::Program]
      def build(tokens, default_name = nil)
        prog = Program.new
        prog.name = tokens.delete("name") || default_name
        prog.api_version = @api_version
        prog.data = node tokens.dup
        prog
      end

      private

      def node(t, inherited_devices = nil)
        errors, warnings = [], []
        instruction, child_nodes =
          case t.keys
          when TRANSITION_KEYS
            build_transition t.fetch("transition"), errors, warnings, inherited_devices
          when SERIAL_KEYS
            build_serial t.fetch("serial"), errors, warnings, inherited_devices
          when PARALLEL_KEYS
            build_parallel t.fetch("parallel"), errors, warnings, inherited_devices
          else
            errors << "Expected exactly one of: transition, serial, parallel. Found #{t.keys}"
            [Program::AST::NoOp.new, []]
          end
        Program::AST::Node.new(instruction, child_nodes, errors, warnings)
      end

      def build_transition(t, errors, warnings, inherited_devices = nil)
        state = build_state(t, errors, warnings)
        devices = build_devices(t, errors, warnings, inherited_devices)
        slp = build_sleep(t, errors, warnings)

        errors << "'transition' requires devices" if devices.empty?
        errors << "Unknown keys in 'transition': #{t.keys.join ", "}" if t.keys.any?

        instruction = Program::AST::Transition.new(state, devices, slp)
        return instruction, []
      end

      def build_serial(t, errors, warnings, inherited_devices = nil)
        lp = build_loop(t, errors, warnings)
        slp = build_sleep(t, errors, warnings)
        devices = build_devices(t, errors, warnings, inherited_devices)
        children = build_steps(t, errors, warnings, devices)

        errors << "'serial' requires steps" if children.empty?
        errors << "Unknown keys in 'serial': #{t.keys.join ", "}" if t.keys.any?

        instruction = Program::AST::SerialControl.new(lp, slp)
        return instruction, children
      end

      def build_parallel(t, errors, warnings, inherited_devices = nil)
        lp = build_loop(t, errors, warnings)
        slp = build_sleep(t, errors, warnings)
        devices = build_devices(t, errors, warnings, inherited_devices)
        children = build_steps(t, errors, warnings, devices)

        errors << "'parallel' requires steps" if children.empty?
        errors << "Unknown keys in 'parallel': #{t.keys.join ", "}" if t.keys.any?

        instruction = Program::AST::ParallelControl.new(lp, slp)
        return instruction, children
      end

      def map_state_keys(state, errors, warnings)
        time = state.delete "time"
        case time
        when Integer, Float
          state["transitiontime"] = (time.to_f * 10).round(0)
        when nil
          # pass
        else
          errors << "'transition.state.time' must be a number"
        end

        ctk = state.delete "ctk"
        case ctk
        when 2000..6530
          state["ct"] = (1_000_000 / ctk).round # https://en.wikipedia.org/wiki/Mired
        when nil
          # pass
        else
          errors << "'transition.state.ctk' must be an integer between 2700 and 6530"
        end

        state
      end

      def build_state(t, errors, warnings)
        state = t.delete "state"
        case state
        when Hash
          map_state_keys state, errors, warnings
        when nil
          errors << "'state' is required in a transition"
          {}
        else
          errors << "Expected 'state' to be an object, got a #{state.class.name}"
          {}
        end
      end

      def build_steps(t, errors, warnings, inherited_devices = nil)
        steps_val = t.delete "steps"
        case steps_val
        when Array
          steps_val.map { |s| node s, inherited_devices }
        when nil
          errors << "Missing 'steps'"
          []
        else
          errors << "'steps' should be an array but is a #{steps_val.class.name}"
          []
        end
      end

      def build_loop(t, errors, warnings)
        loop_val = t.delete "loop"
        case loop_val
        when Hash
          pause = loop_val.delete "pause"
          errors << "'loop.pause' must be an integer. Found '#{pause.class.name}'" if pause and !pause.is_a? Integer

          lp =
            case loop_val.keys
            when INFINITE_KEYS
              loop_val["infinite"] == true ? Program::AST::InfiniteLoop.new : Program::AST::CountedLoop.new(1)
            when COUNT_KEYS
              num = loop_val["count"]
              errors << "'loop.count' must be an integer. Found '#{num.class.name}'" unless num.is_a? Integer
              Program::AST::CountedLoop.new(num)
            when TIMER_KEYS
              build_timer_loop loop_val["timer"], errors, warnings
            when DEADLINE_KEYS
              build_deadline_loop loop_val["until"], errors, warnings
            else
              errors << "'loop' must contain exactly one of: 'infinite', 'count', 'timer', or 'until', and optionally 'pause'. Found: #{loop_val.keys.join ", "}"
              Program::AST::CountedLoop.new(1)
            end
          lp.pause = pause
          lp
        when nil
          Program::AST::CountedLoop.new(1)
        else
          errors << "'loop' must be an object. Found '#{loop_val.class.name}'"
          Program::AST::CountedLoop.new(1)
        end
      end

      def build_timer_loop(t, errors, warnings)
        hours = t.delete "hours"
        minutes = t.delete "minutes"

        errors << "'loop.hours' must be an integer" if hours and !hours.is_a? Integer
        errors << "'loop.minutes' must be an integer" if minutes and !minutes.is_a? Integer
        errors << "Unknown keys in 'loop.timer': #{t.keys.join ", "}" if t.keys.any?

        Program::AST::TimerLoop.new(hours || 0, minutes || 0)
      end

      def build_deadline_loop(t, errors, warnings)
        date = t.delete "date"
        time = t.delete "time"
        errors << "Unknown keys in 'loop.until': #{t.keys.join ", "}" if t.keys.any?

        stop_time = build_stop_time(date, time, errors, warnings)
        Program::AST::DeadlineLoop.new(stop_time)
      end

      def build_sleep(t, errors, warnings)
        sleep_val = t.delete "pause"
        case sleep_val
        when Integer, Float
          sleep_val
        when nil
          nil
        else
          errors << "'pause' must be an integer or float"
          nil
        end
      end

      def build_devices(t, errors, warnings, inherited_devices = nil)
        devices_ref = t.delete("devices") || {}
        return inherited_devices if devices_ref.empty? and inherited_devices

        refs_val, lights_val, groups_val = devices_ref.delete("inputs"), devices_ref.delete("lights"), devices_ref.delete("groups")
        lights = lights_val ? device_names(Program::AST::Light, "lights", lights_val, errors, warnings) : []
        groups = groups_val ? device_names(Program::AST::Group, "groups", groups_val, errors, warnings) : []
        refs =
          case refs_val
          when "$all"
            [Program::AST::DeviceRef.new(:all)]
          when nil
            []
          when Array
            if refs_val.all? { |ref| ref.is_a?(String) && ref =~ DEVICE_REF }
              refs_val.map { |ref|
                n = ref.match(DEVICE_REF).captures[0].to_i
                Program::AST::DeviceRef.new(n)
              }
            else
              errors << "If 'inputs' is an array, it must be an array of input variables (e.g. [$1, $2, ...])"
              []
            end
          else
            errors << "'inputs' must be '$all' or an array of input variables (e.g. [$1, $2, ...])"
            []
          end

        errors << "Unknown keys in 'devices': #{devices_ref.keys.join ", "}" if devices_ref.keys.any?
        lights + groups + refs
      end

      def device_names(type, key, val, errors, warnings)
        if val.is_a?(Array) and val.all? { |name| name.is_a? String }
          val.map { |name| type.new(name) }
        else
          errors << "'#{key}' must be an array of names (found #{val.class.name})"
          []
        end
      end

      def build_stop_time(date_val, time_val, errors, warnings)
        now = Time.now
        d =
          begin
            date_val ? Date.iso8601(date_val) : now.to_date
          rescue Date::Error
            errors << "Invalid date '#{date_val}'. Use \"YYYY-MM-DD\" format."
            Date.today
          end

        hrs, min =
          if time_val.nil?
            [now.hour, now.min]
          elsif time_val.is_a?(String) and time_val =~ HHMM
            time_val.split(":", 2).map(&:to_i)
          else
            errors << "Invalid time '#{time_val}'. Use \"HH:MM\" format."
            [0, 0]
          end

        begin
          t = Time.new(d.year, d.month, d.day, hrs, min, 0, now.utc_offset)
          warnings << "Time (#{t.iso8601}) is already in the past" if t < now
          t
        rescue ArgumentError
          errors << "Invalid datetime (year=#{d.year} month=#{d.month} day=#{d.day} hrs=#{hrs} min=#{min} sec=0 offset=#{now.utc_offset})"
          now
        end
      end
    end
  end
end
