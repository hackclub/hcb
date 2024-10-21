# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                            :bigint           not null, primary key
#  access_level                  :integer          default("user"), not null
#  birthday_ciphertext           :text
#  charge_notifications          :integer          default("email_and_sms"), not null
#  comment_notifications         :integer          default("all_threads"), not null
#  email                         :text
#  full_name                     :string
#  locked_at                     :datetime
#  payout_method_type            :string
#  phone_number                  :text
#  phone_number_verified         :boolean          default(FALSE)
#  preferred_name                :string
#  pretend_is_not_admin          :boolean          default(FALSE), not null
#  receipt_report_option         :integer          default("none"), not null
#  running_balance_enabled       :boolean          default(FALSE), not null
#  seasonal_themes_enabled       :boolean          default(TRUE), not null
#  session_duration_seconds      :integer          default(2592000), not null
#  sessions_reported             :boolean          default(FALSE), not null
#  slug                          :string
#  use_sms_auth                  :boolean          default(FALSE)
#  use_two_factor_authentication :boolean          default(FALSE)
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  payout_method_id              :bigint
#  webauthn_id                   :string
#
# Indexes
#
#  index_users_on_email  (email) UNIQUE
#  index_users_on_slug   (slug) UNIQUE
#
class User < ApplicationRecord
  has_paper_trail skip: [:birthday] # ciphertext columns will still be tracked

  include PublicIdentifiable
  set_public_id_prefix :usr

  include Commentable
  extend FriendlyId

  include Turbo::Broadcastable

  include ApplicationHelper

  has_paper_trail only: [:access_level, :email]

  include PublicActivity::Model
  tracked owner: proc{ |controller, record| record }, recipient: proc { |controller, record| record }, only: [:create, :update]

  include PgSearch::Model
  pg_search_scope :search_name, against: [:full_name, :email, :phone_number], associated_against: { email_updates: :original }, using: { tsearch: { prefix: true, dictionary: "english" } }

  friendly_id :slug_candidates, use: :slugged
  scope :admin, -> { where(access_level: [:admin, :superadmin]) }

  enum :receipt_report_option, {
    none: 0,
    weekly: 1,
    monthly: 2,
  }, prefix: :receipt_report, default: :weekly

  enum :access_level, { user: 0, admin: 1, superadmin: 2 }, scopes: false, default: :user

  has_many :logins
  has_many :login_codes
  has_many :user_sessions, dependent: :destroy
  has_many :organizer_position_invites, dependent: :destroy
  has_many :organizer_positions
  has_many :organizer_position_deletion_requests, inverse_of: :submitted_by
  has_many :organizer_position_deletion_requests, inverse_of: :closed_by
  has_many :webauthn_credentials
  has_many :mailbox_addresses
  has_many :api_tokens
  has_many :email_updates, class_name: "User::EmailUpdate", inverse_of: :user
  has_many :email_updates_created, class_name: "User::EmailUpdate", inverse_of: :updated_by

  has_many :messages, class_name: "Ahoy::Message", as: :user

  has_many :events, through: :organizer_positions

  has_many :managed_events, inverse_of: :point_of_contact

  has_many :g_suite_accounts, inverse_of: :fulfilled_by
  has_many :g_suite_accounts, inverse_of: :creator

  has_many :emburse_transfers
  has_many :emburse_card_requests
  has_many :emburse_cards
  has_many :emburse_transactions, through: :emburse_cards

  has_one :stripe_cardholder
  accepts_nested_attributes_for :stripe_cardholder, update_only: true
  has_many :stripe_cards, through: :stripe_cardholder
  has_many :stripe_authorizations, through: :stripe_cards
  has_many :receipts

  has_many :checks, inverse_of: :creator

  has_many :reimbursement_reports, class_name: "Reimbursement::Report"
  has_many :created_reimbursement_reports, class_name: "Reimbursement::Report", foreign_key: "invited_by_id", inverse_of: :inviter
  has_many :assigned_reimbursement_reports, class_name: "Reimbursement::Report", foreign_key: "reviewer_id", inverse_of: :reviewer
  has_many :approved_expenses, class_name: "Reimbursement::Expense", inverse_of: :approved_by

  has_many :card_grants

  has_one_attached :profile_picture

  has_one :unverified_totp, -> { where(aasm_state: :unverified) }, class_name: "User::Totp", inverse_of: :user
  has_one :totp, -> { where(aasm_state: :verified) }, class_name: "User::Totp", inverse_of: :user

  # a user does not actually belong to its payout method,
  # but this is a convenient way to set up the association.

  belongs_to :payout_method, polymorphic: true, optional: true
  validate :valid_payout_method
  accepts_nested_attributes_for :payout_method

  has_encrypted :birthday, type: :date

  include HasMetrics

  include HasTasks

  before_create :format_number
  before_save :on_phone_number_update

  after_update :update_stripe_cardholder, if: -> { phone_number_previously_changed? || email_previously_changed? }

  after_update :sync_with_loops

  validates_presence_of :full_name, if: -> { full_name_in_database.present? }
  validates_presence_of :birthday, if: -> { birthday_ciphertext_in_database.present? }

  validates :full_name, format: {
    with: /\A[a-zA-ZàáâäãåąčćęèéêëėįìíîïłńòóôöõøùúûüųūÿýżźñçčšžÀÁÂÄÃÅĄĆČĖĘÈÉÊËÌÍÎÏĮŁŃÒÓÔÖÕØÙÚÛÜŲŪŸÝŻŹÑßÇŒÆČŠŽ∂ð.,'-]+ [a-zA-ZàáâäãåąčćęèéêëėįìíîïłńòóôöõøùúûüųūÿýżźñçčšžÀÁÂÄÃÅĄĆČĖĘÈÉÊËÌÍÎÏĮŁŃÒÓÔÖÕØÙÚÛÜŲŪŸÝŻŹÑßÇŒÆČŠŽ∂ð.,' -]+\z/,
    message: "must contain your first and last name, and can't contain special characters.", allow_blank: true,
  }

  validates :email, uniqueness: true, presence: true
  validates_email_format_of :email
  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :phone_number, phone: { allow_blank: true }

  validates :preferred_name, length: { maximum: 30 }

  validate :profile_picture_format

  enum comment_notifications: { all_threads: 0, my_threads: 1, no_threads: 2 }

  enum charge_notifications: { email_and_sms: 0, email: 1, sms: 2, nothing: 3 }, _prefix: :charge_notifications

  comma do
    id
    name
    slug "url" do |slug| "https://hcb.hackclub.com/users/#{slug}/admin" end
    email
    transactions_missing_receipt_count "Missing Receipts"
  end

  after_save do
    if use_sms_auth_previously_changed?
      if use_sms_auth
        create_activity(key: "user.enabled_sms_auth")
      else
        create_activity(key: "user.disabled_sms_auth")
      end
    end
  end

  scope :currently_online, -> { where(id: UserSession.where("last_seen_at > ?", 15.minutes.ago).pluck(:user_id)) }

  # admin? takes into account an admin user's preference
  # to pretend to be a non-admin, normal user
  def admin?
    (self.access_level == "admin" || self.access_level == "superadmin") && !self.pretend_is_not_admin
  end

  # admin_override_pretend? ignores an admin user's
  # preference to pretend not to be an admin.
  def admin_override_pretend?
    self.access_level == "admin" || self.access_level == "superadmin"
  end

  def make_admin!
    admin!
  end

  def remove_admin!
    user!
  end

  def first_name(legal: false)
    @first_name ||= (namae(legal:)&.given || namae(legal:)&.particle)&.split(" ")&.first
  end

  def last_name(legal: false)
    @last_name ||= namae(legal:)&.family&.split(" ")&.last
  end

  def initial_name
    @initial_name ||= if name.strip.split(" ").count == 1
                        name
                      else
                        "#{(first_name || last_name)[0..20]} #{(last_name || first_name)[0, 1]}"
                      end
  end

  def safe_name
    # stripe requires names to be 24 chars or less, and must include a last name
    return name unless name.length > 24
    return full_name unless full_name.length > 24

    initial_name
  end

  def name
    preferred_name.presence || full_name || email_handle
  end

  def possessive_name
    possessive(name)
  end

  def initials
    words = name.split(/[^[[:word:]]]+/)
    words.any? ? words.map(&:first).join.upcase : name
  end

  def pretty_phone_number
    Phonelib.parse(self.phone_number).national
  end

  def admin_dropdown_description
    "#{name} (#{email})"
  end

  def birthday?
    birthday.present? && birthday.month == Date.today.month && birthday.day == Date.today.day
  end

  def seasonal_themes_disabled?
    !seasonal_themes_enabled?
  end

  def locked?
    locked_at.present?
  end

  def lock!
    update!(locked_at: Time.now)

    # Invalidate all sessions
    user_sessions.destroy_all
  end

  def unlock!
    update!(locked_at: nil)
  end

  def onboarding?
    full_name.blank?
  end

  def active_mailbox_address
    self.mailbox_addresses.activated.first
  end

  def receipt_bin
    User::ReceiptBin.new(self)
  end

  def hcb_code_ids_missing_receipt
    @hcb_code_ids_missing_receipt ||= begin
      user_cards = stripe_cards.includes(:event).where.not(event: { category: :salary }) + emburse_cards.includes(:emburse_transactions)
      user_cards.flat_map { |card| card.hcb_codes.missing_receipt.receipt_required.pluck(:id) }
    end
  end

  def transactions_missing_receipt
    @transactions_missing_receipt ||= begin
      return HcbCode.none unless hcb_code_ids_missing_receipt.any?

      user_hcb_codes = HcbCode.where(id: hcb_code_ids_missing_receipt).order(created_at: :desc)
    end
  end

  def transactions_missing_receipt_count
    @transactions_missing_receipt_count ||= begin
      transactions_missing_receipt.size
    end
  end

  def build_payout_method(params)
    return unless payout_method_type

    self.payout_method = payout_method_type.constantize.new(params)
  end

  def email_address_with_name
    ActionMailer::Base.email_address_with_name(email, name)
  end

  def hack_clubber?
    return events.organized_by_hack_clubbers.any?
  end

  def teenager?
    birthday&.after?(19.years.ago) || events.high_school_hackathon.any? || events.organized_by_teenagers.any?
  end

  def last_seen_at
    user_sessions.maximum(:last_seen_at)
  end

  def last_login_at
    user_sessions.maximum(:created_at)
  end

  def email_charge_notifications_enabled?
    charge_notifications_email? || charge_notifications_email_and_sms?
  end

  def sms_charge_notifications_enabled?
    charge_notifications_sms? || charge_notifications_email_and_sms?
  end

  def sync_with_loops
    new_user = full_name_before_last_save.blank? && !onboarding?
    UserService::SyncWithLoops.new(user_id: id, new_user:).run
  end

  private

  def update_stripe_cardholder
    stripe_cardholder&.update!(stripe_email: email, stripe_phone_number: phone_number)
  end

  def namae(legal: false)
    if legal
      @legal_namae ||= Namae.parse(full_name).first
    else
      @namae ||= Namae.parse(name).first || Namae.parse(name_simplified).first || Namae::Name.new(given: name_simplified)
    end
  end

  def name_simplified
    name.split(/[^[[:word:]]]+/).join(" ")
  end

  def email_handle
    @email_handle ||= email.split("@").first
  end

  def slug_candidates
    slug = normalize_friendly_id self.name
    # From https://github.com/norman/friendly_id/issues/480
    sequence = User.where("slug LIKE ?", "#{slug}-%").size + 2
    [slug, "#{slug} #{sequence}"]
  end

  def profile_picture_format
    return unless profile_picture.attached?
    return if profile_picture.blob.content_type.start_with? "image/"

    profile_picture.purge_later
    errors.add(:profile_picture, "needs to be an image")
  end

  def format_number
    self.phone_number = Phonelib.parse(self.phone_number).sanitized
  end

  def on_phone_number_update
    # if we previously have a phone number and the phone number is not null
    if phone_number_changed?
      # turn all this stuff off until they reverify
      self.phone_number_verified = false
      self.use_sms_auth = false
    end
  end

  def valid_payout_method
    unless payout_method_type.nil? || payout_method.is_a?(User::PayoutMethod::Check) || payout_method.is_a?(User::PayoutMethod::AchTransfer) || payout_method.is_a?(User::PayoutMethod::PaypalTransfer)
      errors.add(:payout_method, "is an invalid method, must be check or ACH transfer")
    end
  end

end
