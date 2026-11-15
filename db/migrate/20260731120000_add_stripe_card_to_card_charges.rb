# frozen_string_literal: true

class AddStripeCardToCardCharges < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    add_reference :card_charges, :stripe_card, index: { algorithm: :concurrently }

    add_foreign_key :card_charges, :stripe_cards, validate: false

    validate_foreign_key :card_charges, :stripe_cards
  end

  def down
    remove_reference :card_charges, :stripe_card, index: { algorithm: :concurrently }
  end

end
