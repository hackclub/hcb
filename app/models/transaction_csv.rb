# frozen_string_literal: true

# == Schema Information
#
# Table name: transaction_csvs
#
#  id         :bigint           not null, primary key
#  aasm_state :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class TransactionCsv < ApplicationRecord
  include AASM

  has_one_attached :file

  validates :file, attached: true

  aasm do
    state :pending, initial: true
    state :processing
    state :processed

    event :mark_processing do
      transitions from: :pending, to: :processing
    end

    event :mark_processed do
      transitions from: :processing, to: :processed
    end
  end

end
