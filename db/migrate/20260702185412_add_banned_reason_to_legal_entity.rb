class AddBannedReasonToLegalEntity < ActiveRecord::Migration[8.0]
  def change
    add_column :legal_entities, :banned_reason, :string
  end
end
