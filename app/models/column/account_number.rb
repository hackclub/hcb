# frozen_string_literal: true

# == Schema Information
#
# Table name: column_account_numbers
#
#  id                        :bigint           not null, primary key
#  account_number_bidx       :string
#  account_number_ciphertext :text
#  bic_code_ciphertext       :text
#  deposit_only              :boolean          default(TRUE), not null
#  routing_number_ciphertext :text
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  column_id                 :text
#  event_id                  :bigint           not null
#
# Indexes
#
#  index_column_account_numbers_on_account_number_bidx  (account_number_bidx)
#  index_column_account_numbers_on_event_id             (event_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
module Column
  class AccountNumber < ApplicationRecord
    belongs_to :event

    has_encrypted :account_number, :routing_number, :bic_code

    blind_index :account_number

    before_create :create_column_account_number

    validate :event_is_not_demo_mode

    has_paper_trail

    private

    def create_column_account_number
      account_number = ColumnService.post("/bank-accounts/#{ColumnService::Accounts::FS_MAIN}/account-numbers", description: "##{event.id} (#{event.name})", idempotency_key: self.id.to_s)

      self.column_id = account_number["id"]
      self.account_number = account_number["account_number"]
      self.routing_number = account_number["routing_number"]
      self.bic_code = account_number["bic"]
    end

    def event_is_not_demo_mode
      errors.add(:base, "Can't create an account number for a Playground Mode org") if event.demo_mode?
    end

  end
end
