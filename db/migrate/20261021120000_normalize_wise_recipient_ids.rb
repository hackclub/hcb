# frozen_string_literal: true

class NormalizeWiseRecipientIds < ActiveRecord::Migration[8.1]
  def up
    # Only repair recognizable Wise recipient URLs; do not guess at other invalid IDs.
    pattern = '^[[:space:]]*https?://wise[.]com/recipients/([[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12})/?(?:[?#].*)?[[:space:]]*$'

    %w[user_payout_method_wise_transfers wise_transfers].each do |table|
      safety_assured do
        execute <<~SQL
          UPDATE #{table}
          SET wise_recipient_id = substring(wise_recipient_id from #{connection.quote(pattern)})
          WHERE wise_recipient_id ~ #{connection.quote(pattern)}
        SQL
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "The original Wise recipient URLs cannot be recovered"
  end

end
