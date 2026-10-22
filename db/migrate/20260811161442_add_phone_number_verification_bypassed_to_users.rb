# frozen_string_literal: true

class AddPhoneNumberVerificationBypassedToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :phone_number_verification_bypassed, :boolean, null: false, default: false
  end

end
