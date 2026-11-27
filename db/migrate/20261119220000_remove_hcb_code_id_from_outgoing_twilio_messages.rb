# frozen_string_literal: true

class RemoveHcbCodeIdFromOutgoingTwilioMessages < ActiveRecord::Migration[8.1]
  def change
    # Outgoing Twilio messages point at the transaction's ledger item now. The
    # column is already ignored by OutgoingTwilioMessage and nothing writes
    # it. Drop it; Postgres drops its index with it.
    safety_assured do
      remove_column :outgoing_twilio_messages, :hcb_code_id, :bigint
    end
  end

end
