# frozen_string_literal: true

# == Schema Information
#
# Table name: raffles
#
#  id         :bigint           not null, primary key
#  program    :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_raffles_on_program_and_user_id  (program,user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Raffle < ApplicationRecord
  belongs_to :user
  validates :program, presence: true

end
