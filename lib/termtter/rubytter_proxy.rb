config.set_default(:memory_cache_size, 10000)

module Termtter
  class RubytterProxy
    include Hookable

    attr_reader :rubytter

    def initialize(*args)
      @rubytter = Rubytter.new(*args)
    end

    def method_missing(method, *args, &block)
      if @rubytter.respond_to?(method)
        result = nil
        begin
          modified_args = args
          hooks = self.class.get_hooks("pre_#{method}")
          hooks.each do |hook|
            modified_args = hook.call(*modified_args)
          end

          result = call_rubytter_or_use_cache(method, *modified_args, &block)

          self.class.call_hooks("post_#{method}", *args)
        rescue HookCanceled
        end
        result
      else
        super
      end
    end

    def status_cache_store
      # TODO: DB store とかにうまいこと切り替えられるようにしたい
      @status_cache_store ||= MemoryCache.new(config.memory_cache_size)
    end

    def call_rubytter_or_use_cache(method, *args, &block)
      case method
      when :show
        status_cache_store[args[0].to_i] ||= call_rubytter(method, *args, &block)
      when :home_timeline, :user_timeline, :friends_timeline, :search
        statuses = call_rubytter(method, *args, &block)
        statuses.each do |status|
          status_cache_store[status.id] = status
        end
        statuses
      else
        call_rubytter(method, *args, &block)
      end
    end

    def call_rubytter(method, *args, &block)
      config.retry.times do
        begin
          timeout(config.timeout) do
            return @rubytter.__send__(method, *args, &block)
          end
        rescue TimeoutError
        end
      end
      raise TimeoutError, 'execution expired'
    end
  end
end
