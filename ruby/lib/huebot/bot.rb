module Huebot
  # The Huebot runtime
  class Bot
    Error = Class.new(StandardError)

    def initialize(device_mapper, waiter: nil, logger: nil)
      @device_mapper = device_mapper
      @logger = logger || Logging::NullLogger.new
      @waiter = waiter || Waiter
    end

    def execute(program)
      @logger.log :start, {program: program.name}
      exec program.data
      @logger.log :stop, {program: program.name}
    end

    private

    def exec(node)
      case node.instruction
      when Program::AST::Transition
        transition node.instruction
      when Program::AST::SerialControl
        serial node.children, node.instruction
      when Program::AST::ParallelControl
        parallel node.children, node.instruction
      else
        raise Error, "Unexpected instruction '#{node.instruction.class.name}'"
      end
    end

    def transition(i)
      time = (i.state["transitiontime"] || 4).to_f / 10
      devices = map_devices i.devices
      @logger.log :transition, {devices: devices.map(&:name)}

      wait i.pause.pre if i.pause&.pre
      devices.map { |device|
        Thread.new {
          # TODO error handling
          _res = device.set_state i.state
          @logger.log :set_state, {device: device.name, state: i.state, result: nil}
          wait Program::AST::Num.new(time) if i.wait
        }
      }.map(&:join)
      wait i.pause.post if i.pause&.post
    end

    def serial(nodes, i)
      wait i.pause.pre if i.pause&.pre
      control_loop(i.loop) { |loop_type|
        @logger.log :serial, {loop: loop_type}
        nodes.each { |node|
          exec node
        }
      }
      wait i.pause.post if i.pause&.post
    end

    def parallel(nodes, i)
      wait i.pause.pre if i.pause&.pre
      control_loop(i.loop) { |loop_type|
        @logger.log :parallel, {loop: loop_type}
        nodes.map { |node|
          Thread.new {
            # TODO error handling
            exec node
          }
        }.map(&:join)
      }
      wait i.pause.post if i.pause&.post
    end

    def control_loop(lp)
      case lp
      when Program::AST::InfiniteLoop
        loop {
          wait lp.pause.pre if lp.pause&.pre
          yield :infinite
          wait lp.pause.post if lp.pause&.post
        }
      when Program::AST::CountedLoop
        number(lp.n).round.times {
          wait lp.pause.pre if lp.pause&.pre
          yield :counted
          wait lp.pause.post if lp.pause&.post
        }
      when Program::AST::DeadlineLoop
        until Time.now >= lp.stop_time
          wait lp.pause.pre if lp.pause&.pre
          yield :deadline
          wait lp.pause.post if lp.pause&.post
        end
      when Program::AST::TimerLoop
        sec = ((lp.hours * 60) + lp.minutes) * 60
        time = 0
        until time >= sec
          start = Time.now
          wait lp.pause.pre if lp.pause&.pre
          yield :timer
          wait lp.pause.post if lp.pause&.post
          time += (Time.now - start).round
        end
      else
        raise Error, "Unexpected loop type '#{lp.class.name}'"
      end
    end

    def map_devices(refs)
      refs.reduce([]) { |acc, ref|
        devices =
          case ref
          when Program::AST::Light
            [@device_mapper.light!(ref.name)]
          when Program::AST::Group
            [@device_mapper.group!(ref.name)]
          when Program::AST::DeviceRef
            Array(@device_mapper.var! ref.ref)
          else
            raise Error, "Unknown device reference '#{ref.class.name}'"
          end
        acc + devices
      }
    end

    def wait(n)
      seconds = number n
      @logger.log :pause, {time: seconds}
      @waiter.call seconds
    end

    def number(n)
      case n
      when Program::AST::Num
        n.n
      when Program::AST::RandomNum
        rand(n.min..n.max)
      else
        raise Error, "Unknown numeric type. Expected Program::AST::Num, Program::AST::NRandomNum, found: #{n.class.name}"
      end
    end

    module Waiter
      def self.call(seconds)
        sleep seconds
      end
    end
  end
end
