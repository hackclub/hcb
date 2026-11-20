# frozen_string_literal: true

# == Schema Information
#
# Table name: outgoing_twilio_messages
#
#  id                :bigint           not null, primary key
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
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
  # The transaction the text was about, if any, where a photo texted back is
  # attached. Nil for texts that aren't about a transaction (User::SendSmsJob).
  belongs_to :ledger_item, class_name: "Ledger::Item", optional: true

  # Messages used to point at the transaction's HCB code. Nothing writes the
  # column any more; it's dropped once no running code expects it.
  self.ignored_columns += ["hcb_code_id"]

  validates_presence_of :twilio_message

end
