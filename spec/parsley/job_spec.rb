require 'sidekiq/worker'
require 'parsley/job'

describe Parsley::Job do
  it 'adds #perform_with_infrastructure_serialized with mixin before #perform definition' do
    class AJobWithJobMixinBeforePerform
      include Parsley::Job
      def perform; end
    end

    AJobWithJobMixinBeforePerform.method_defined?(:perform_with_infrastructure_serialized).should be_true
  end

  it 'adds #perform_with_infrastructure_serialized with mixin after #perform definition' do
    class AJobWithJobMixinAfterPerform
      def perform; end
      include Parsley::Job
    end

    AJobWithJobMixinAfterPerform.method_defined?(:perform_with_infrastructure_serialized).should be_true
  end

  it 'notifies the infrastructure when the job is finished' do
    class AJob
      include Parsley::Job
      def perform(*)
        'foo'
      end
    end

    infrastructure = mock(:Infrastructure).as_null_object
    infrastructure.should_receive(:notify_job_finished).with(AJob, 'foo')

    AJob.new.perform(infrastructure)
  end

  it 'allows queue specification' do
    class AJob
      include Parsley::Job

      queue :critical

      def perform(*)
      end
    end
    AJob.get_sidekiq_options['queue'].should == :critical
  end

  it 'drops failed job only after many retries' do
    class AJob
      include Parsley::Job

      def perform(*)
      end
    end
    AJob.get_sidekiq_options['retry'].should == 1_000_000
  end

  it 'stores backtrace' do
    class AJob
      include Parsley::Job

      def perform(*)
      end
    end
    AJob.get_sidekiq_options['backtrace'].should be_true
  end
end
