# frozen_string_literal: true

class Raffle < ApplicationRecord
  belongs_to :user
  validates :program, presence: true

end
