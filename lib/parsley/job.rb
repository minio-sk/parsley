class Parsley
  module Job
    def self.included(base)
      base.send(:include, Sidekiq::Worker)
      base.extend ClassMethods
      base.sidekiq_options retry: 1_000_000
      if base.method_defined?(:perform)
        base.send(:alias_method, :original_perform, :perform)
        base.send(:alias_method, :perform, :perform_with_infrastructure_serialized)
      else
        # This aliases perform method as soon as it is added
        base.class_eval <<-EOS
          def self.method_added(method)
            return if method != :perform || method_defined?(:original_perform)
            alias_method(:original_perform, :perform)
            alias_method(:perform, :perform_with_infrastructure_serialized)
          end
        EOS
      end
    end

    def perform_with_infrastructure_serialized(*args)
      infrastructure = args.pop.constantize
      perform_with_infrastructure(*args + [infrastructure])
    end

    def perform_with_infrastructure(*args)
      infrastructure = args.last
      result = original_perform(*args)
      infrastructure.notify_job_finished(self)
      result
    end

    module ClassMethods
      def queue(name)
        sidekiq_options(queue: name)
      end
    end
  end
end
