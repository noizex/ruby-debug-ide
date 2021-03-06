module Debugger
  module MultiProcess
    class << self
      def pre_child(options = nil)
        require 'socket'
        require 'ostruct'

        host = ENV['DEBUGGER_HOST']
        child_process_ports = if ENV['DEBUGGER_CHILD_PROCESS_PORTS']
                                ENV['DEBUGGER_CHILD_PROCESS_PORTS'].split(/-/)
                              else
                                nil
                              end
        port = find_free_port(host, child_process_ports)

        options ||= OpenStruct.new(
            'frame_bind'  => false,
            'host'        => host,
            'load_mode'   => false,
            'port'        => port,
            'stop'        => false,
            'tracing'     => false,
            'int_handler' => true,
            'cli_debug'   => (ENV['DEBUGGER_CLI_DEBUG'] == 'true'),
            'notify_dispatcher' => true,
            'child_process_ports' => child_process_ports
        )

        start_debugger(options)
      end

      def start_debugger(options)
        if Debugger.started?
          # we're in forked child, only need to restart control thread
          Debugger.breakpoints.clear
          Debugger.control_thread = nil
          Debugger.start_control(options.host, options.port, options.notify_dispatcher)
        end

        if options.int_handler
          # install interruption handler
          trap('INT') { Debugger.interrupt_last }
        end

        # set options
        Debugger.keep_frame_binding = options.frame_bind
        Debugger.tracing = options.tracing
        Debugger.cli_debug = options.cli_debug

        Debugger.prepare_debugger(options)
      end


      def find_free_port(host, child_process_ports)
        if child_process_ports.nil?
          server = TCPServer.open(host, 0)
          port   = server.addr[1]
          server.close
          port
        else
          ports = Range.new(child_process_ports[0], child_process_ports[1]).to_a
          begin
            raise "Could not find open port in range #{child_process_ports[0]} to #{child_process_ports[1]}" if ports.empty?

            port = ports.sample
            server = TCPServer.open(host, port)
            server.close
            port
          rescue Errno::EADDRINUSE
            ports.delete(port)
            retry
          end
        end
      end
    end
  end
end
