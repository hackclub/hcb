# frozen_string_literal: true

class CreateGrants < ActiveRecord::Migration[8.1]
  def change
    create_table :grants do |t|
      t.references :event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :sent_by, null: false, foreign_key: { to_table: :users }

      # The fulfillment the recipient chose: a CardGrant (virtual card, also the
      # pending/invitation record) or a Reimbursement::Report. Unique so a single
      # card grant or report can only ever back one Grant.
      t.references :grantable, polymorphic: true, null: false, index: { unique: true }

      t.timestamps
    end
  end
end
