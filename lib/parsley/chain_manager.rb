class Parsley
  class ChainManager
    def initialize(infrastructure)
      @definitions = Definitions.new(infrastructure)
    end

    def define(job_sequence)
      job_sequence.each_cons(2) do |job_class, successor_class|
        @definitions.create_or_update(job_class, successor_class)
      end
    end

    def job_finished(job)
      sequence = @definitions.sequence_for(job)
      sequence.enqueue
      @definitions.clear(job)
    end

    def notify(source, args)
      sequence = @definitions.sequence_for(source)
      sequence.notify(args)
    end

    def halt(source)
      sequence = @definitions.sequence_for(source)
      sequence.halt
    end

    class Sequence
      def initialize(successors, infrastructure)
        @successors = successors
        @infrastructure = infrastructure
        @messages = []
        @halted = false
      end

      def notify(args)
        @messages << args
      end

      def halt
        @halted = true
      end

      def enqueue
        unless @halted
          @successors.each do |successor_class|
            if @messages.any?
              @messages.each { |message| @infrastructure.enqueue(successor_class, *message) }
            else
              @infrastructure.enqueue(successor_class)
            end
          end
        end
      end
    end

    class Definitions
      def initialize(infrastructure)
        @definitions = Hash.new { |h, k| h[k] = [] }
        @sequences = {}
        @infrastructure = infrastructure
      end

      def create_or_update(job_class, successor_class)
        @definitions[job_class] << successor_class
      end

      def sequence_for(job)
        successors = @definitions[job.class]
        @sequences[job] ||= Sequence.new(successors, @infrastructure)
      end

      def clear(job)
        @sequences.delete(job)
      end
    end
  end
end
