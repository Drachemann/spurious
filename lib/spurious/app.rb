require 'thor'
require 'eventmachine'
require 'spurious/command/state'
require 'spurious/command/ports'
require 'timeout'

module Spurious
  class App < Thor
    include Thor::Actions

    DEFAULT_PORT = 4590
    DEFAULT_HOST = 'localhost'

    namespace :spurious

    class_option :server_port, :type => :string, :default => ENV.fetch('SPURIOUS_SERVER_PORT', DEFAULT_PORT), :desc => "The port of spurious server"
    class_option :server_host, :type => :string, :default => ENV.fetch('SPURIOUS_SERVER_HOST', DEFAULT_HOST), :desc => "The host address of spurious server"
    def initialize(*args)
      super
    end


    def self.state_methods
      %w(init start update stop delete).each do |meth|
        desc meth, "#{meth} for the spurious containers"
        define_method(meth) do
          event_loop meth.to_sym
        end
      end
    end


    state_methods

    method_option :'json', :type => :boolean, :default => false, :desc => 'Prints out ports as a json string'
    desc "ports", "List ports for the spurious containers"
    def ports

      if server_available? then
        EventMachine.run do
            EventMachine::connect options[:server_host], options[:server_port], Spurious::Command::Ports, :ports, self
        end
      end
    end

    protected

    def server_timeout
      options[:server_host] == DEFAULT_HOST ? 1 : 5
    end

    def server_available?
      available = true

      Timeout.timeout(server_timeout) do
        begin
          TCPSocket.new(options[:server_host], options[:server_port])
        rescue Exception
          available = false
          say <<-eos

#{set_color("Connection to spurious server: #{options[:server_host]}:#{options[:server_port]} has timed out.", :red)}

#{set_color('To check the status of the server, run:', :white)}
#{set_color('$ spurious-server status', :cyan)}

#{set_color('To start the server, run:', :white)}
#{set_color('$ spurious-server start', :cyan)}

          eos
        end
      end

      available

    end


    def event_loop(type)

      if server_available? then
        EventMachine.run do
            EventMachine::connect options[:server_host], options[:server_port], Spurious::Command::State, type, self
        end
      end

    end
  end
end
