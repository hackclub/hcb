# frozen_string_literal: true

# == Schema Information
#
# Table name: payees
#
#  id              :bigint           not null, primary key
#  preferred_name  :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  event_id        :bigint           not null
#  legal_entity_id :bigint           not null
#
# Indexes
#
#  index_payees_on_event_id         (event_id)
#  index_payees_on_legal_entity_id  (legal_entity_id)
#
class Payee < ApplicationRecord
  belongs_to :event
  belongs_to :legal_entity

end
