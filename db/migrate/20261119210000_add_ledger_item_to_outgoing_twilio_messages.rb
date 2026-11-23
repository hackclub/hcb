# frozen_string_literal: true

# An outgoing Twilio message records which transaction we texted someone about,
# so a photo texted back within the reply window can be attached to it. The
# receipt goes on the transaction's ledger item now
# (https://github.com/hackclub/hcb/issues/14106), so the message moves from the
# transaction's HCB code to its ledger item too. Nullable: texts that aren't
# about a transaction never have one, and the rest are backfilled separately.
# hcb_code_id stays until the readers have switched.
class AddLedgerItemToOutgoingTwilioMessages < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # Each step commits on its own, so they're safe to re-run after a lock timeout.
  def up
    add_reference :outgoing_twilio_messages, :ledger_item, index: { algorithm: :concurrently, if_not_exists: true }, if_not_exists: true

    # The message is a record of what we sent, so it outlives its transaction.
    add_foreign_key :outgoing_twilio_messages, :ledger_items, on_delete: :nullify, validate: false, if_not_exists: true
    validate_foreign_key :outgoing_twilio_messages, :ledger_items
  end

  def down
    remove_reference :outgoing_twilio_messages, :ledger_item, foreign_key: { to_table: :ledger_items }, index: true
  end

end
