# frozen_string_literal: true

# == Schema Information
#
# Table name: organizer_position_deletion_requests
#
#  id                                           :bigint           not null, primary key
#  closed_at                                    :datetime
#  reason                                       :text
#  subject_emails_should_be_forwarded           :boolean          default(FALSE), not null
#  subject_has_active_cards                     :boolean          default(FALSE), not null
#  subject_has_outstanding_expenses_expensify   :boolean          default(FALSE), not null
#  subject_has_outstanding_transactions_emburse :boolean          default(FALSE), not null
#  subject_has_outstanding_transactions_stripe  :boolean          default(FALSE), not null
#  created_at                                   :datetime         not null
#  updated_at                                   :datetime         not null
#  closed_by_id                                 :bigint
#  organizer_position_id                        :bigint
#  submitted_by_id                              :bigint
#
# Indexes
#
#  index_organizer_deletion_requests_on_organizer_position_id     (organizer_position_id)
#  index_organizer_position_deletion_requests_on_closed_by_id     (closed_by_id)
#  index_organizer_position_deletion_requests_on_submitted_by_id  (submitted_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (closed_by_id => users.id)
#  fk_rails_...  (organizer_position_id => organizer_positions.id)
#  fk_rails_...  (submitted_by_id => users.id)
#
class OrganizerPositionDeletionRequest < ApplicationRecord
  has_paper_trail

  include Commentable

  belongs_to :submitted_by, class_name: "User"
  belongs_to :closed_by, class_name: "User", optional: true
  belongs_to :organizer_position, with_deleted: true
  has_one :event, through: :organizer_position

  scope :under_review, -> { where(closed_at: nil) }

  after_create_commit { OrganizerPositionDeletionRequestMailer.with(opdr: self).notify_operations.deliver_later }

  validates_presence_of :reason

  def under_review?
    closed_at.nil?
  end

  def status
    if organizer_position.deleted_at.present?
      :organizer_deleted
    elsif under_review?
      :under_review
    else
      :closed
    end
  end

  def status_badge_type
    if organizer_position.deleted_at.present?
      :primary
    elsif under_review?
      :pending
    else
      :success
    end
  end

  def close(closed_by)
    raise StandardError.new("Already closed") unless self.closed_at.nil?

    self.closed_by = closed_by
    self.closed_at = Time.now
    self.save
  end

  def open
    self.closed_by = nil
    self.closed_at = nil
    self.save
  end

  def organizer_missing_receipts
    organizer_position.user.transactions_missing_receipt.select do |hcb_code|
      hcb_code.event == organizer_position.event
    end
  end

  def organizer_active_cards
    organizer_stripe_cards.active
  end

  def organizer_last_signee?
    event.signees.size == 1 && organizer_position.signee?
  end

  private

  def organizer_stripe_cards
    organizer_position.user.stripe_cards.where(event: organizer_position.event)
  end

end
