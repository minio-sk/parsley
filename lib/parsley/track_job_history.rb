class Parsley
  def enqueue(job, *args)
    raise UnsupportedJobError unless job.include?(Parsley::Job)
    if args.last.is_a?(Hash) && args.last[:history]
      history = args.pop[:history]
    end
    @queue.enqueue(job, *args, self, history || [])
  end

  def notify_job_finished(job_class, results, history)
    @job_chain[job_class].each do |successor|
      results = [results] unless results.kind_of? Array
      results.each do |result|
        unless result === false
          if result
            encoded_result = result.respond_to?(:serialize) ? result.serialize : result
            enqueue(successor, encoded_result, history: history)
          else
            enqueue(successor, history: history)
          end
        end
      end
    end
  end

  module Job
    def perform_with_infrastructure_serialized(*args)
      history = args.pop
      infrastructure = args.pop.constantize
      perform_with_infrastructure(*args + [infrastructure, history])
    end

    def perform_with_infrastructure(*args)
      history = args.pop
      infrastructure = args.last
      result = original_perform(*args)
      args.pop
      infrastructure.notify_job_finished(self.class, result, history + [[self.class.name, args]])
      result
    end
  end

  class InstantQueue
    def self.enqueue(job, *args, infrastructure, history)
      job.new.perform_with_infrastructure(*args + [infrastructure, history])
    end
  end

  class SidekiqQueue
    def self.enqueue(job, *args, infrastructure, history)
      job.perform_async(*args + [infrastructure.serialize, history])
    end
  end
end
