class Parsley
  class InstantQueue
    def self.enqueue(job, *args, infrastructure)
      job.new.perform_with_infrastructure(*args + [infrastructure])
    end
  end
end
