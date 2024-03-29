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
      RANDOM_KEYS = ["random"].freeze
      MIN_MAX = ["min", "max"].freeze
      TIMER_KEYS = ["timer"].freeze
      DEADLINE_KEYS = ["until"].freeze
      HHMM = /\A[0-9]{2}:[0-9]{2}\Z/.freeze
      PERCENT_CAPTURE = /\A([0-9]+)%\Z/.freeze
      MIN_KELVIN = 2000
      MAX_KELVIN = 6530
      MAX_BRI = 254

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
        if t.nil?
          errors << "'transition' may not be blank"
          t = {}
        end

        state = build_state(t, errors, warnings)
        devices = build_devices(t, errors, warnings, inherited_devices)
        pause = build_pause(t, errors, warnings)
        wait = @api_version >= 1.1 ? build_wait(t, errors, warnings) : true

        errors << "'transition' requires devices" if devices.empty?
        errors << "Unknown keys in 'transition': #{t.keys.join ", "}" if t.keys.any?

        instruction = Program::AST::Transition.new(state, devices, wait, pause)
        return instruction, []
      end

      def build_serial(t, errors, warnings, inherited_devices = nil)
        if t.nil?
          errors << "'serial' may not be blank"
          t = {}
        end

        lp = build_loop(t, errors, warnings)
        pause = build_pause(t, errors, warnings)
        devices = build_devices(t, errors, warnings, inherited_devices)
        children = build_steps(t, errors, warnings, devices)

        errors << "'serial' requires steps" if children.empty?
        errors << "Unknown keys in 'serial': #{t.keys.join ", "}" if t.keys.any?

        instruction = Program::AST::SerialControl.new(lp, pause)
        return instruction, children
      end

      def build_parallel(t, errors, warnings, inherited_devices = nil)
        if t.nil?
          errors << "'parallel' may not be blank"
          t = {}
        end

        lp = build_loop(t, errors, warnings)
        pause = build_pause(t, errors, warnings)
        devices = build_devices(t, errors, warnings, inherited_devices)
        children = build_steps(t, errors, warnings, devices)

        errors << "'parallel' requires steps" if children.empty?
        errors << "Unknown keys in 'parallel': #{t.keys.join ", "}" if t.keys.any?

        instruction = Program::AST::ParallelControl.new(lp, pause)
        return instruction, children
      end

      def map_state_keys(state, errors, warnings)
        # bugfix to YAML - it parses the "on" key as a Boolean
        case state.delete true
        when true
          state["on"] = true
        when false
          state["on"] = false
        end

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
        when MIN_KELVIN..MAX_KELVIN
          state["ct"] = (1_000_000 / ctk).round # https://en.wikipedia.org/wiki/Mired
        when nil
          # pass
        else
          errors << "'transition.state.ctk' must be an integer between #{MIN_KELVIN} and #{MAX_KELVIN}"
        end

        case state["bri"]
        when Integer, nil
          # pass
        when PERCENT_CAPTURE
          n = $1.to_i
          if n >= 0 and n <= 100
            percent = n * 0.01
            state["bri"] = (MAX_BRI * percent).round
          else
            errors << "'transition.state.bri' must be an integer or a percent between 0% and 100%"
          end
        else
          errors << "'transition.state.bri' must be an integer or a percent between 0% and 100%"
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
          pause = build_pause(loop_val, errors, warnings)
          lp =
            case loop_val.keys
            when INFINITE_KEYS
              loop_val.fetch("infinite") == true ? Program::AST::InfiniteLoop.new : Program::AST::CountedLoop.new(Program::AST::Num.new(1))
            when COUNT_KEYS
              num = loop_val.fetch("count")
              errors << "'loop.count' must be an integer. Found '#{num.class.name}'" unless num.is_a? Integer
              Program::AST::CountedLoop.new(Program::AST::Num.new(num))
            when RANDOM_KEYS
              n = build_random loop_val, errors, warnings
              Program::AST::CountedLoop.new(n)
            when TIMER_KEYS
              build_timer_loop loop_val.fetch("timer"), errors, warnings
            when DEADLINE_KEYS
              build_deadline_loop loop_val.fetch("until"), errors, warnings
            else
              errors << "'loop' must contain exactly one of: 'infinite', 'count', 'timer', or 'until', and optionally 'pause'. Found: #{loop_val.keys.join ", "}"
              Program::AST::CountedLoop.new(Program::AST::Num.new(1))
            end
          lp.pause = pause
          lp
        when nil
          Program::AST::CountedLoop.new(Program::AST::Num.new(1))
        else
          errors << "'loop' must be an object. Found '#{loop_val.class.name}'"
          Program::AST::CountedLoop.new(Program::AST::Num.new(1))
        end
      end

      def build_random(t, errors, warnings)
        random = t.delete("random") || {}
        min = build_random_n(random, "min", errors, warnings)
        max = build_random_n(random, "max", errors, warnings)
        errors << "'random.max' must be greater than 'random.min'" unless max > min
        errors << "Unknown keys in 'random': #{random.keys.join ", "}" if random.keys.any?
        Program::AST::RandomNum.new(min, max)
      end

      def build_random_n(t, name, errors, warnings)
        n = t.delete name
        case n
        when Integer, Float
          if n >= 0
            n
          else
            errors << "'random.#{name}' must be >= 0, found #{n}"
            0
          end
        else
          errors << "'random.#{name}' must be an integer or float > 0, found #{n.class.name}"
          0
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

      def build_pause(t, errors, warnings)
        case @api_version
        when 1.0 then build_pause_1_0(t, errors, warnings)
        when 1.1 then build_pause_1_1(t, errors, warnings)
        when 1.2 then build_pause_1_2(t, errors, warnings)
        else raise Error, "Unknown api version '#{@api_version}'"
        end
      end

      def build_pause_1_0(t, errors, warnings)
        pause_val = t.delete "pause"
        case pause_val
        when Integer, Float
          Program::AST::Pause.new(nil, Program::AST::Num.new(pause_val))
        when nil
          nil
        else
          errors << "'pause' must be an integer or float"
          nil
        end
      end

      def build_pause_1_1(t, errors, warnings)
        pause_val = t.delete "pause"
        case pause_val
        when Integer, Float
          Program::AST::Pause.new(nil, Program::AST::Num.new(pause_val))
        when Hash
          pre = pause_val.delete "before"
          post = pause_val.delete "after"
          errors << "'pause.before' must be an integer or float" unless pre.nil? or pre.is_a? Integer or pre.is_a? Float
          errors << "'pause.after' must be an integer or float" unless post.nil? or post.is_a? Integer or post.is_a? Float
          errors << "Unknown keys in 'pause': #{pause_val.keys.join ", "}" if pause_val.keys.any?
          pre = Program::AST::Num.new(pre) if pre
          post = Program::AST::Num.new(post) if post
          Program::AST::Pause.new(pre, post)
        when nil
          nil
        else
          errors << "'pause' must be an integer or float, or an object with 'before' and/or 'after'"
          nil
        end
      end

      def build_pause_1_2(t, errors, warnings)
        pause_val = t.delete "pause"
        case pause_val
        when Integer, Float
          Program::AST::Pause.new(nil, Program::AST::Num.new(pause_val))
        when Hash
          pre = build_pause_part(pause_val, "before", errors, warnings)
          post = build_pause_part(pause_val, "after", errors, warnings)
          errors << "'pause' requires one or both of 'before' or 'after'" if pre.nil? and post.nil?
          errors << "Unknown keys in 'pause': #{pause_val.keys.join ", "}" if pause_val.keys.any?
          Program::AST::Pause.new(pre, post)
        when nil
          nil
        else
          errors << "'pause' must be an integer or float, or an object with 'before' and/or 'after'"
          nil
        end
      end

      def build_pause_part(t, part, errors, warnings)
        val = t.delete part
        case val
        when nil
          nil
        when Integer, Float
          Program::AST::Num.new(val)
        when Hash
          if @api_version < 1.2
            errors << "Unknown 'pause.#{part}' type (#{val.class.name})"
            return Program::AST::Num.new(1)
          end

          case val.keys
          when RANDOM_KEYS
            build_random val, errors, warnings
          else
            errors << "Expected 'pause.#{part}' to contain 'random', found #{val.keys.join ", "}"
            Program::AST::Num.new(1)
          end
        else
          errors << "Unknown 'pause.#{part}' type (#{val.class.name})"
          Program::AST::Num.new(1)
        end
      end

      def build_wait(t, errors, warnings)
        wait = t.delete "wait"
        case wait
        when true, false
          wait
        when nil
          true
        else
          errors << "'transition.wait' must be true or false"
          true
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
