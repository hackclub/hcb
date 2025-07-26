# frozen_string_literal: true

# == Schema Information
#
# Table name: w9s
#
#  id             :bigint           not null, primary key
#  entity_type    :string           not null
#  signed_at      :datetime         not null
#  url            :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  entity_id      :bigint           not null
#  uploaded_by_id :bigint
#
# Indexes
#
#  index_w9s_on_uploaded_by_id  (uploaded_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (uploaded_by_id => users.id)
#
class W9 < ApplicationRecord
  belongs_to :entity, polymorphic: true
  belongs_to :uploaded_by, class_name: "User"

  has_paper_trail

  def user
    entity if entity.is_a?(User)
  end

  validate do
    if user.nil?
      errors.add(:entity, "must be a user")
    end
  end

end
