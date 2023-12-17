module Huebot
  class Bot
    Error = Class.new(StandardError)

    def initialize(device_mapper)
      @device_mapper = device_mapper
      #@client = device_mapper.bridge.client
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
      if lp.count
        case lp.count
        when Float::INFINITY
          loop { yield }
        else
          lp.count.times { yield }
        end
      else
        hrs = lp.hours || 0
        min = lp.minutes || 0
        sec = ((hrs * 60) + min) * 60
        time = 0
        until time >= sec
          start = Time.now
          yield
          time += (Time.now - start).round
        end
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
