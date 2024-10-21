# frozen_string_literal: true

class SuggestTagsJob < ApplicationJob
  queue_as :low
  def perform(event_id:, hcb_code_id: nil)
    if hcb_code_id
      HcbCodeService::Generate::SuggestedTags.new(hcb_code: HcbCode.find(hcb_code_id), event: Event.find(event_id)).run!
    else
      transactions = TransactionGroupingEngine::Transaction::All.new(event_id:).run
      transactions.each do |transaction|
        HcbCodeService::Generate::SuggestedTags.new(hcb_code: transaction.local_hcb_code, event: Event.find(event_id)).run!
      end
    end
  end

end
