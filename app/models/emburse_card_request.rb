# frozen_string_literal: true

# == Schema Information
#
# Table name: emburse_card_requests
#
#  id                          :bigint           not null, primary key
#  accepted_at                 :datetime
#  canceled_at                 :datetime
#  daily_limit                 :bigint
#  fulfilled_at                :datetime
#  full_name                   :string
#  is_virtual                  :boolean
#  notes                       :text
#  rejected_at                 :datetime
#  shipping_address            :text
#  shipping_address_city       :string
#  shipping_address_state      :string
#  shipping_address_street_one :string
#  shipping_address_street_two :string
#  shipping_address_zip        :string
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  creator_id                  :bigint
#  emburse_card_id             :bigint
#  event_id                    :bigint
#  fulfilled_by_id             :bigint
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (fulfilled_by_id => users.id)
#
class EmburseCardRequest < ApplicationRecord
  include Rejectable
  include Commentable

  belongs_to :creator, class_name: "User"
  belongs_to :fulfilled_by, class_name: "User", optional: true
  belongs_to :event
  belongs_to :emburse_card, optional: true

  delegate :emburse_department_id, to: :event

  validates :full_name, presence: true
  validates :full_name, length: { maximum: 21 }
  validate :status_accepted_canceled_or_rejected

  scope :outstanding, -> { where(accepted_at: nil) }
  scope :accepted, -> { where.not(id: outstanding) }
  scope :under_review, -> { where(rejected_at: nil, canceled_at: nil, accepted_at: nil) }

  def status
    return "rejected" if rejected_at.present?
    return "canceled" if canceled_at.present?
    return "accepted" if accepted_at.present?

    "under review"
  end

  def status_badge_type
    s = status.to_sym
    return :success if s == :accepted
    return :error if s == :rejected
    return :muted if s == :canceled

    :pending
  end

  def shipping_address_full
    # NOTE: when HCB was first written, EmburseCardRequest had a single field for
    # address. We later switched to a more structured address format
    # (street_one, street_two, city, state, zip) but this method wraps both
    # for backwards compatibility.
    if shipping_address.blank?
      street_two = shipping_address_street_two ? "#{shipping_address_street_two}\n" : ""
      "#{shipping_address_street_one}\n#{street_two}#{shipping_address_city}, #{shipping_address_state} #{shipping_address_zip}"
    else
      shipping_address
    end
  end

  def under_review?
    rejected_at.nil? && canceled_at.nil? && accepted_at.nil?
  end

end
