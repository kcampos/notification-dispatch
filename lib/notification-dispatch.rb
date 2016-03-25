#require "notification-dispatch/version"

module Notification
  module Dispatch

    class Client
      attr_reader :key_map, :clients, :msg_classes, :conn

      KEY_MAPS = {
        #:aws => {:access_key => 'AWS_ACCESS_KEY', :secret_key => 'AWS_SECRET_KEY'},
        :datadog => {:api_key => 'DATADOG_API_KEY'},
        :keen    => {
          :project_id => 'KEEN_PROJECT_ID',
          :master_key => 'KEEN_MASTER_KEY',
          :write_key  => 'KEEN_WRITE_KEY',
          :read_key   => 'KEEN_READ_KEY'
        }
      }

      def initialize
        @key_map     = {}
        @msg_classes = {}
        @clients     = lambda { return get_active_clients }
      end

      def is_active?
        @key_map.values.empty? ? false : @key_map.values.all? {|key| !ENV[key].nil? && !ENV[key].empty?}
      end

      def clients
        @clients.call
      end

      def has_active_clients?
        !clients.empty?
      end

      def handle_message?(msg_class, msg_type)
        @msg_classes.has_key?(msg_class) && @msg_classes[msg_class].include?(msg_type)
      end

      # Return number of successful msgs
      def message(msg_class, msg_type, subject, msg, opts={})
        success = clients.inject([]) do |result, client|
          resp = false
          resp = client.message(msg_class, msg_type, subject, msg, opts) if(client.handle_message?(msg_class, msg_type))
          resp ? result << resp : result
        end
        success.size
      end

      private

      # Iterate over keys in client_key_map and return array of active clients
      def get_active_clients
        KEY_MAPS.each_key.inject([]) do |res, client|
          client_class = Notification::Dispatch.const_get(client.to_s.capitalize.intern).new
          client_class.is_active? ? res.push(client_class) : res
        end
      end

    end

    class Datadog < Client
      attr_reader :key

      def initialize
        @key_map     = self.class::KEY_MAPS[:datadog]
        @key         = ENV[@key_map[:api_key]]
        @msg_classes = {:event => [:error, :warning, :info, :success]}
        @conn        = self.is_active? ? connect : nil
      end

      def connect
        require 'dogapi'
        Dogapi::Client.new(key)
      end

      def message(msg_class, msg_type, subject, msg, opts={})
        raise "Datadog: unsupported msg_class and/or msg_type" unless(handle_message?(msg_class, msg_type))
        options = {:source => 'my apps', :tags => [], :aggregation_key => nil}
        options.merge!(opts)
        @conn.emit_event(Dogapi::Event.new(
          msg,
          :msg_title        => subject,
          :tags             => options[:tags], 
          :alert_type       => msg_type.to_s,
          :source_type_name => options[:source],
          :aggregation_key  => options[:aggregation_key])
        )

        true
      end
    end

    class Keen < Client
      def initialize
        @key_map     = self.class::KEY_MAPS[:keen]
        @msg_classes = {:metric => [:counter, :gauge]}
        @conn        = self.is_active? ? connect : nil
      end

      def connect
        require 'keen'
      end

      def message(msg_class, msg_type, subject, msg, opts={})
        raise "Keen: unsupported msg_class and/or msg_type" unless(handle_message?(msg_class, msg_type))
        raise "must pass collection and hash of data in opts" unless(!opts[:collection].nil? && !opts[:data].nil?)
        opts[:data].class == Array ? ::Keen.publish_batch(opts[:collection] => opts[:data]) : ::Keen.publish(opts[:collection], opts[:data])
      end
    end

  end
end
