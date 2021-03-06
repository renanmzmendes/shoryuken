module Shoryuken
  module Worker
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def perform_async(body, options = {})
        options ||= {}
        options[:message_attributes] ||= {}
        options[:message_attributes]['shoryuken_class'] = {
          string_value: self.to_s,
          data_type: 'String'
        }

        body = JSON.dump(body) if body.is_a?(Hash)
        options[:message_body] = body

        Shoryuken::Client.queues(get_shoryuken_options['queue']).send_message(options)
      end

      def perform_in(interval, body, options = {})
        interval = interval.to_f
        now = Time.now.to_f
        ts = (interval < 1_000_000_000 ? (now + interval).to_f : interval)

        delay = (ts - now).ceil

        raise 'The maximum allowed delay is 15 minutes' if delay > 15 * 60

        perform_async(body, options.merge(delay_seconds: delay))
      end

      alias_method :perform_at, :perform_in

      def server_middleware
        @server_chain ||= Shoryuken.server_middleware.dup
        yield @server_chain if block_given?
        @server_chain
      end

      def shoryuken_options(opts = {})
        @shoryuken_options = get_shoryuken_options.merge(stringify_keys(Hash(opts)))
        queue = @shoryuken_options['queue']
        if queue.respond_to? :call
          queue = queue.call
          @shoryuken_options['queue'] = queue
        end

        Shoryuken.register_worker(queue, self)
      end

      def auto_visibility_timeout?
        !!get_shoryuken_options['auto_visibility_timeout']
      end

      def get_shoryuken_options # :nodoc:
        @shoryuken_options || Shoryuken.default_worker_options
      end

      def stringify_keys(hash) # :nodoc:
        hash.keys.each do |key|
          hash[key.to_s] = hash.delete(key)
        end
        hash
      end
    end
  end
end
