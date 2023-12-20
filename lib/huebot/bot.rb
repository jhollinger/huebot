module Huebot
  # The Huebot runtime
  class Bot
    Error = Class.new(StandardError)

    def initialize(device_mapper)
      @device_mapper = device_mapper
    end

    def execute(program)
      exec program.data
    end

    private

    def exec(node)
      i = node.instruction
      case i
      when Program::AST::Transition
        transition i.state, i.devices, i.sleep
      when Program::AST::SerialControl
        serial node.children, i.loop, i.sleep
      when Program::AST::ParallelControl
        parallel node.children, i.loop, i.sleep
      else
        raise Error, "Unexpected instruction '#{i.class.name}'"
      end
    end

    def transition(state, device_refs, sleep_time = nil)
      time = (state["transitiontime"] || 4).to_f / 10
      devices = map_devices device_refs
      devices.map { |device|
        Thread.new {
          # TODO error handling
          device.set_state state
          wait time
        }
      }.map(&:join)
      wait sleep_time if sleep_time
    end

    def serial(nodes, lp, sleep_time = nil)
      control_loop(lp) {
        nodes.map { |node|
          exec node
        }
      }
      wait sleep_time if sleep_time
    end

    def parallel(nodes, lp, sleep_time = nil)
      control_loop(lp) {
        nodes.map { |node|
          Thread.new {
            # TODO error handling
            exec node
          }
        }.map(&:join)
      }
      wait sleep_time if sleep_time
    end

    def control_loop(lp)
      case lp
      when Program::AST::InfiniteLoop
        loop {
          yield
          wait lp.pause if lp.pause
        }
      when Program::AST::CountedLoop
        lp.n.times {
          yield
          wait lp.pause if lp.pause
        }
      when Program::AST::DeadlineLoop
        until Time.now >= lp.stop_time
          yield
          wait lp.pause if lp.pause
        end
      when Program::AST::TimerLoop
        sec = ((lp.hours * 60) + lp.minutes) * 60
        time = 0
        until time >= sec
          start = Time.now
          yield
          wait lp.pause if lp.pause
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

    def wait(seconds)
      # TODO sleep in small bursts in a loop so can detect if an Interrupt was caught
      sleep seconds
    end
  end
end
