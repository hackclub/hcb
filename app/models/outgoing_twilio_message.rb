# frozen_string_literal: true

# == Schema Information
#
# Table name: outgoing_twilio_messages
#
#  id                :bigint           not null, primary key
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  hcb_code_id       :bigint
#  ledger_item_id    :bigint
#  twilio_message_id :bigint
#
# Indexes
#
#  index_outgoing_twilio_messages_on_hcb_code_id        (hcb_code_id)
#  index_outgoing_twilio_messages_on_ledger_item_id     (ledger_item_id)
#  index_outgoing_twilio_messages_on_twilio_message_id  (twilio_message_id)
#
# Foreign Keys
#
#  fk_rails_...  (ledger_item_id => ledger_items.id) ON DELETE => nullify
#
class OutgoingTwilioMessage < ApplicationRecord
  # How long after we text about a charge a photo texted back is attached to that charge
  # (the receipt SMS in CanonicalPendingTransaction::SendTwilioReceiptMessageJob says "within ten minutes")
  RECEIPT_REPLY_WINDOW = 10.minutes

  belongs_to :twilio_message
  belongs_to :hcb_code, optional: true
  # The transaction the text was about, if any, where a photo texted back is
  # attached. Nil for texts that aren't about a transaction (User::SendSmsJob)
  # and, until the backfill has run, for texts from before this column existed.
  belongs_to :ledger_item, class_name: "Ledger::Item", optional: true

  validates_presence_of :twilio_message

end
