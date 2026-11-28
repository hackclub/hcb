# frozen_string_literal: true

class AddReplacementReasonToStripeCards < ActiveRecord::Migration[8.1]
  def change
    add_column :stripe_cards, :replacement_reason, :string
  end
end
