require 'parsley'
require 'parsley/track_job_history'

describe Parsley do
  let(:queue) { Parsley::InstantQueue }
  let(:infrastructure) { Parsley.new(queue: queue) }

  class ImportExtract
    include Parsley::Job

    def perform(*)
      5234
    end
  end
  class CleanExtract
    include Parsley::Job

    def perform(*)
      98
    end
  end
  class DeduplicateExtract
    include Parsley::Job

    def perform(*)
    end
  end

  it 'logs previous jobs and their args in a bogus sidekiq argument' do
    infrastructure.chain ImportExtract, CleanExtract, DeduplicateExtract

    queue.should_receive(:enqueue).with(ImportExtract, infrastructure, []).and_call_original
    queue.should_receive(:enqueue).with(CleanExtract, 5234, infrastructure, [["ImportExtract", []]]).and_call_original
    queue.should_receive(:enqueue).with(DeduplicateExtract, 98, infrastructure, [["ImportExtract", []], ["CleanExtract", [5234]]])

    infrastructure.enqueue(ImportExtract)
  end
end
