# frozen_string_literal: true

# == Schema Information
#
# Table name: organizer_position_invites
#
#  id                                     :bigint           not null, primary key
#  accepted_at                            :datetime
#  cancelled_at                           :datetime
#  initial                                :boolean          default(FALSE)
#  initial_control_allowance_amount_cents :integer
#  is_signee                              :boolean          default(FALSE)
#  rejected_at                            :datetime
#  role                                   :integer          default("manager"), not null
#  slug                                   :string
#  created_at                             :datetime         not null
#  updated_at                             :datetime         not null
#  event_id                               :bigint           not null
#  organizer_position_id                  :bigint
#  sender_id                              :bigint
#  user_id                                :bigint           not null
#
# Indexes
#
#  index_organizer_position_invites_on_event_id               (event_id)
#  index_organizer_position_invites_on_organizer_position_id  (organizer_position_id)
#  index_organizer_position_invites_on_sender_id              (sender_id)
#  index_organizer_position_invites_on_slug                   (slug) UNIQUE
#  index_organizer_position_invites_on_user_id                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (organizer_position_id => organizer_positions.id)
#  fk_rails_...  (sender_id => users.id)
#  fk_rails_...  (user_id => users.id)
#

# OrganizerPositionInvites are used to invite users - whether they already
# exist or not - to manage an Event.
#
# One of the oddities we need to deal with is that the User being invited will
# usually not already exist in the database. Here's how we're dealing with it.
#
# Scenario 1: User being invited does not exist in the database
#
#  1. User is created with the invited email.
#  2. OrganizerPositionInvite is created. Event, email and user are set.
#  3. Notification email is sent to invitee
#  4. Invitee goes to bank and logs in for the first time, using the previously created user.
#
# Scenario 2: User being invited exists in the database
#
#  1. OrganizerPositionInvite is created. Event, email, and user all get set on
#     creation.
#
class OrganizerPositionInvite < ApplicationRecord
  has_paper_trail

  include PublicIdentifiable
  set_public_id_prefix :ivt

  include FriendlyId
  include OrganizerPosition::HasRole

  include PublicActivity::Model
  tracked owner: proc{ |controller, record| controller&.current_user }, event_id: proc { |controller, record| record.event.id }, recipient: proc { |controller, record| record.user }, only: [:create]

  friendly_id :slug_candidates, use: :slugged

  scope :pending, -> { where(accepted_at: nil, rejected_at: nil, cancelled_at: nil) }
  # tmb@hackclub: this is the scope that the SessionHelper looks to assign un-assigned invites. we need to include cancelled invites so that we can assign users to them
  scope :pending_assign, -> { where(accepted_at: nil, rejected_at: nil) }

  belongs_to :event
  belongs_to :user
  belongs_to :sender, class_name: "User"

  belongs_to :organizer_position, optional: true
  has_many :organizer_position_contracts, class_name: "OrganizerPosition::Contract"

  validate :not_already_organizer
  validate :not_already_invited, on: :create
  validates :accepted_at, absence: true, if: -> { rejected_at.present? }
  validates :rejected_at, absence: true, if: -> { accepted_at.present? }

  validate :initial_control_allowance_amount_cents_nil_for_non_members

  after_create_commit do
    unless pending_signature?
      user == sender ? accept : deliver
    end
  end

  def organizer_position_contract
    organizer_position_contracts.where.not(aasm_state: :voided).last
  end

  def pending_signature?
    is_signee && organizer_position_contracts.where(aasm_state: :signed).none?
  end

  def deliver
    OrganizerPositionInvitesMailer.with(invite: self).notify.deliver_later
  end

  def accept(show_onboarding: true)
    if cancelled?
      self.errors.add(:base, "was canceled!")
      return false
    end

    if accepted?
      self.errors.add(:base, "already accepted!")
      return false
    end

    if pending_signature?
      self.errors.add(:base, "requires a signed contract!")
      return false
    end

    self.organizer_position = OrganizerPosition.new(
      event:,
      user:,
      role:,
      is_signee:,
      first_time: show_onboarding,
    )

    self.accepted_at = Time.current

    ActiveRecord::Base.transaction do
      self.save!

      if initial_control_allowance_amount_cents.present?
        # Create control
        organizer_position.spending_controls.create!

        # Create allowance
        organizer_position.active_spending_control.allowances.create!(authorized_by_id: sender_id, amount_cents: initial_control_allowance_amount_cents, memo: "Initial allowance") unless initial_control_allowance_amount_cents.zero?
      end

      true
    end
  end

  def accepted?
    accepted_at.present?
  end

  def reject
    if cancelled?
      self.errors.add(:base, "was canceled!")
      return false
    end

    if rejected?
      self.errors.add(:base, "already rejected!")
      return false
    end

    self.rejected_at = Time.current

    self.save
  end

  def rejected?
    rejected_at.present?
  end

  def cancel
    if accepted?
      self.errors.add(:user, "has already accepted this invite!")
      return false
    end

    if rejected?
      self.errors.add(:user, "has already rejected this invite!")
      return false
    end

    self.cancelled_at = Time.current

    self.save
  end

  def cancelled?
    cancelled_at.present?
  end

  def slug_candidates
    slug = normalize_friendly_id("#{event.try(:name)} #{user.email}")
    # https://github.com/norman/friendly_id/issues/480
    sequence = OrganizerPositionInvite.where("slug LIKE ?", "#{slug}-%").size + 2
    [slug, "#{slug} #{sequence}"]
  end

  def signee?
    is_signee
  end

  private

  def not_already_organizer
    if event && event.users.pluck(:email).include?(user.email)
      self.errors.add(:user, "is already an organizer of this event!")
    end
  end

  def not_already_invited
    if event && event.organizer_position_invites.includes(:user).pending.pluck(:email).include?(user.email)
      self.errors.add(:user, "already has a pending invite!")
    end
  end

  def initial_control_allowance_amount_cents_nil_for_non_members
    if role == "manager" && initial_control_allowance_amount_cents.present?
      self.errors.add(:user, "can not set an initial control allowance for a manager")
    end
  end

end
