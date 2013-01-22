class Parsley
  class SidekiqQueue
    def self.enqueue(job, *args, infrastructure)
      job.perform_async(*args + [infrastructure.serialize])
    end
  end
end
