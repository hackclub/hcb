# frozen_string_literal: true

class AddForeignKeySubscriptionIdToHcbCodes < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :hcb_codes, :subscriptions, on_delete: :nullify, validate: false
  end

end
