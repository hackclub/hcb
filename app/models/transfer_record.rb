# frozen_string_literal: true

# == Schema Information
#
# Table name: transfer_records
#
#  id                :bigint           not null, primary key
#  amount_cents      :integer          default(0), not null
#  recipient_email   :string
#  recipient_name    :string
#  status            :integer          default("in_transit"), not null
#  transferable_type :string           not null
#  created_at        :datetime         not null
#  event_id          :bigint           not null
#  transferable_id   :bigint           not null
#
# Indexes
#
#  index_transfer_records_on_event_id                 (event_id)
#  index_transfer_records_on_event_id_and_created_at  (event_id,created_at)
#  index_transfer_records_on_event_id_and_status      (event_id,status)
#  index_transfer_records_on_transferable             (transferable_type,transferable_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
class TransferRecord < ApplicationRecord
  belongs_to :transferable, polymorphic: true
  belongs_to :event

  enum :status, { in_transit: 0, deposited: 1, canceled: 2 }

  scope :recent_first, -> { order(created_at: :desc) }

  include PgSearch::Model
  pg_search_scope :search_recipient,
                  against: [:recipient_name, :recipient_email],
                  using: { tsearch: { prefix: true, dictionary: "english" } }

end
