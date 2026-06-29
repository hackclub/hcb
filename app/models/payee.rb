# frozen_string_literal: true

# == Schema Information
#
# Table name: payees
#
#  id              :bigint           not null, primary key
#  display_name    :string           not null
#  email           :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  event_id        :bigint           not null
#  legal_entity_id :bigint
#
# Indexes
#
#  index_payees_on_event_id                      (event_id)
#  index_payees_on_legal_entity_id               (legal_entity_id)
#  index_payees_on_legal_entity_id_and_event_id  (legal_entity_id,event_id) UNIQUE
#
class Payee < ApplicationRecord
  include PgSearch::Model

  belongs_to :event
  belongs_to :legal_entity, optional: true

  validates_uniqueness_of :legal_entity_id, scope: [:event_id], allow_nil: true

  pg_search_scope :search, against: [:display_name, :email], using: { tsearch: { prefix: true, dictionary: "english" } }

end
