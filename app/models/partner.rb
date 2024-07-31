# frozen_string_literal: true

# == Schema Information
#
# Table name: partners
#
#  id                        :bigint           not null, primary key
#  api_key_bidx              :string
#  api_key_ciphertext        :text
#  external                  :boolean          default(TRUE), not null
#  logo                      :text
#  name                      :text
#  public_stripe_api_key     :string
#  slug                      :string           not null
#  stripe_api_key_ciphertext :text
#  webhook_url               :string
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  representative_id         :bigint
#
# Indexes
#
#  index_partners_on_api_key_bidx       (api_key_bidx) UNIQUE
#  index_partners_on_representative_id  (representative_id)
#
# Foreign Keys
#
#  fk_rails_...  (representative_id => users.id)
#
class Partner < ApplicationRecord
  self.ignored_columns = ["docusign_envelope_id", "signed_contract"]

  has_paper_trail skip: [:stripe_api_key, :api_key] # ciphertext columns will still be tracked
  has_encrypted :stripe_api_key, :api_key

  blind_index :api_key

  EXCLUDED_SLUGS = %w(connect api donations donation connects organization organizations).freeze

  has_many :events
  has_many :partnered_signups
  has_many :partner_donations, through: :events

  # The default `representative` association accessor method is overridden below
  belongs_to :representative, class_name: "User"

  validates :slug, exclusion: { in: EXCLUDED_SLUGS }, uniqueness: true
  validates :api_key, presence: true, uniqueness: true

  after_initialize do
    self.api_key ||= new_api_key
  end

  def add_user_to_partnered_event!(user_email:, event:)
    # @msw: I take full responsibility the aweful way this is being implemented.
    # To my future self, or other devs: this should be moved to a service, and
    # be given proper validations.

    user = User.find_by(email: user_email)
    unless user
      User.create!(email: user_email)
    end

    position_exists = event.users.include?(user)
    invite_exists = event.organizer_position_invites.where(email: user_email).any?

    unless position_exists || invite_exists
      partnered_email = "hcb+#{event.partner.slug}@hackclub.com"
      invite_sender = User.find_by(email: partnered_email)
      invite_sender ||= User.create!(email: partnered_email)
      OrganizerPositionInviteService::Create.new(
        event:,
        sender: invite_sender,
        user_email:,
      ).run!
    end

    self
  end

  def regenerate_api_key!
    self.api_key = new_api_key
    self.save!
  end

  def default_org_sponsorship_fee
    0.10
  end

  # Representatives are users that represent a Partner. There is only one
  # representative per Partner. This is necessary because much of our UI relies
  # on the existence of a user. For automated processes, this user
  # representative stands in for a "real" user who should normally be performing
  # that process.
  #   Example:
  #     A Partner has a representative user who invites initial users to
  #     an organization.
  #
  # Overrides the default `representative` accessor association to create the
  # representative user if it doesn't already exist.
  def representative
    return super unless super.nil?

    representative_email = if external
                             "hcb+#{slug || "partner_#{id}"}@hackclub.com"
                           else
                             "hcb@hackclub.com"
                           end

    transaction do
      # Double check that the user doesn't exist. (It could exist and just not
      # be associated)
      user = User.find_by(email: representative_email)
      if user.nil?
        user = User.create!(email: representative_email, full_name: self.name)
      end

      self.representative = user
      self.save!

      user
    end
  rescue => e
    Airbrake.notify("Failed to create representative user for partner #{self.id}", e)
    nil
  end

  def self.new_api_key
    self.new.send(:new_api_key)
  end

  private

  def new_api_key
    "hcbk_#{SecureRandom.hex(32)}"
  end

end
