# frozen_string_literal: true

# == Schema Information
#
# Table name: legal_entity_users
#
#  id              :bigint           not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  legal_entity_id :bigint           not null
#  user_id         :bigint           not null
#
class LegalEntityUser < ApplicationRecord
  belongs_to :legal_entity
  belongs_to :user

  validate :person_entities_have_one_user
  validate :user_only_has_one_person_entity

  private

  def person_entities_have_one_user
    if legal_entity.person? && LegalEntityUser.where(legal_entity:).excluding(self).any?
      errors.add(:base, "Legal entities with type person can only have one user")
    end
  end

  def user_only_has_one_person_entity
    if legal_entity.person? && LegalEntityUser.where(user:).excluding(self).any?
      errors.add(:base, "Users can only have one person legal entity")
    end
  end

end
