# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                            :bigint           not null, primary key
#  access_level                  :integer          default("user"), not null
#  birthday_ciphertext           :text
#  cards_locked                  :boolean          default(FALSE), not null
#  charge_notifications          :integer          default("email_and_sms"), not null
#  comment_notifications         :integer          default("all_threads"), not null
#  creation_method               :integer
#  email                         :text             not null
#  full_name                     :string
#  joined_as_teenager            :boolean
#  locked_at                     :datetime
#  payout_method_type            :string
#  phone_number                  :text
#  phone_number_verified         :boolean          default(FALSE)
#  preferred_name                :string
#  pretend_is_not_admin          :boolean          default(FALSE), not null
#  receipt_report_option         :integer          default("weekly"), not null
#  running_balance_enabled       :boolean          default(FALSE), not null
#  seasonal_themes_enabled       :boolean          default(TRUE), not null
#  session_validity_preference   :integer          default(259200), not null
#  sessions_reported             :boolean          default(FALSE), not null
#  slug                          :string
#  teenager                      :boolean
#  use_sms_auth                  :boolean          default(FALSE)
#  use_two_factor_authentication :boolean          default(FALSE)
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  discord_id                    :string
#  payout_method_id              :bigint
#  webauthn_id                   :string
#
# Indexes
#
#  index_users_on_discord_id  (discord_id) UNIQUE
#  index_users_on_email       (email) UNIQUE
#  index_users_on_slug        (slug) UNIQUE
#
class User < ApplicationRecord
  BLACKLISTED_DOMAINS = ["aboodbab.com"].freeze

  has_paper_trail skip: [:birthday] # ciphertext columns will still be tracked

  include PublicIdentifiable
  set_public_id_prefix :usr

  include Commentable
  extend FriendlyId

  include Turbo::Broadcastable

  include ApplicationHelper
  prepend MemoWise

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

  enum :access_level, { user: 0, admin: 1, superadmin: 2, auditor: 3 }, scopes: false, default: :user

  enum :creation_method, {
    login: 0,
    reimbursement_report: 1,
    organizer_position_invite: 2,
    card_grant: 3,
    grant: 4,
    application_form: 5
  }

  has_many :logins
  has_many :applications, class_name: "Event::Application", inverse_of: :user
  has_many :login_codes
  has_many :backup_codes, class_name: "User::BackupCode", inverse_of: :user, dependent: :destroy
  has_many :user_sessions, class_name: "User::Session", dependent: :destroy
  has_many :organizer_position_invites, dependent: :destroy
  has_many :organizer_position_invite_requests, class_name: "OrganizerPositionInvite::Request", inverse_of: :requester, dependent: :destroy
  has_many :contracts, through: :organizer_position_invites
  has_many :organizer_positions
  has_many :reader_organizer_positions, -> { where(organizer_positions: { role: :reader }) }, class_name: "OrganizerPosition", inverse_of: :user
  has_many :organizer_position_deletion_requests, inverse_of: :submitted_by
  has_many :organizer_position_deletion_requests, inverse_of: :closed_by
  has_many :webauthn_credentials
  has_many :mailbox_addresses
  has_many :api_tokens
  has_many :email_updates, class_name: "User::EmailUpdate", inverse_of: :user
  has_many :email_updates_created, class_name: "User::EmailUpdate", inverse_of: :updated_by

  has_many :referral_programs, class_name: "Referral::Program", inverse_of: :creator
  has_many :referral_links, class_name: "Referral::Link", inverse_of: :creator

  has_many :messages, class_name: "Ahoy::Message", as: :user

  has_many :events, through: :organizer_positions
  has_many :reader_events, through: :reader_organizer_positions, class_name: "Event", source: :event

  has_many :event_follows, class_name: "Event::Follow"
  has_many :followed_events, through: :event_follows, source: :event

  has_many :managed_events, inverse_of: :point_of_contact, class_name: "Event"

  has_many :event_groups, class_name: "Event::Group"

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

  has_many :jobs, as: :entity, class_name: "Employee"
  has_many :job_payments, through: :jobs, source: :payments, class_name: "Employee::Payment"

  has_many :card_grants

  has_many :wise_transfers

  has_one_attached :profile_picture
  validates :profile_picture, size: { less_than_or_equal_to: 5.megabytes }, if: -> { attachment_changes["profile_picture"].present? }

  has_many :w9s, class_name: "W9", as: :entity

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

  before_update(if: :will_save_change_to_birthday?) { self.teenager = is_teenager? }
  before_update(if: :will_save_change_to_birthday?) { self.joined_as_teenager = was_teenager_on_join? }

  before_create :format_number
  before_save :on_phone_number_update
  validate :second_factor_present_for_2fa

  after_update :update_stripe_cardholder, if: -> { phone_number_previously_changed? || email_previously_changed? }

  after_update_commit :send_onboarded_email, if: -> { was_onboarding? && !onboarding? }

  after_update :queue_sync_with_loops_job

  before_update :set_default_seasonal_theme

  validates_presence_of :full_name, if: -> { full_name_in_database.present? }
  validates_presence_of :birthday, if: -> { birthday_ciphertext_in_database.present? }

  validate :must_be_13_or_older, if: :will_save_change_to_birthday?

  def must_be_13_or_older
    return if birthday.blank?

    calculated_age = age_on(Date.current)
    if calculated_age && calculated_age < 13
      errors.add(:birthday, "You must be at least 13 years old")
    end
  end

  validates :full_name, format: {
    with: /\A[a-zA-ZàáâäãåąčćęèéêëėįìíîïłńòóôöõøùúûüųūÿýżźñçčšžÀÁÂÄÃÅĄĆČĖĘÈÉÊËÌÍÎÏĮŁŃÒÓÔÖÕØÙÚÛÜŲŪŸÝŻŹÑßÇŒÆČŠŽ∂ð.,'-]+ [a-zA-ZàáâäãåąčćęèéêëėįìíîïłńòóôöõøùúûüųūÿýżźñçčšžÀÁÂÄÃÅĄĆČĖĘÈÉÊËÌÍÎÏĮŁŃÒÓÔÖÕØÙÚÛÜŲŪŸÝŻŹÑßÇŒÆČŠŽ∂ð.,' -]+\z/,
    message: "must contain your first and last name, and can't contain special characters.", allow_blank: true,
  }

  validates :email, uniqueness: true, presence: true
  validates_email_format_of :email
  normalizes :email, with: ->(email) { email.strip.downcase }
  validate :email_not_in_blacklisted_domains, on: :create

  validates :phone_number, phone: { allow_blank: true }

  validates :preferred_name, length: { maximum: 30 }

  validates(:session_validity_preference, presence: true, inclusion: { in: SessionsHelper::SESSION_DURATION_OPTIONS.values })

  validate :profile_picture_format

  validate(:admins_cannot_disable_2fa, on: :update)

  validates :discord_id, uniqueness: { message: "is already linked to another user. Please contact hcb@hackclub.com if this is unexpected." }, allow_nil: true

  enum :comment_notifications, { all_threads: 0, my_threads: 1, no_threads: 2 }

  enum :charge_notifications, { email_and_sms: 0, email: 1, sms: 2, nothing: 3 }, prefix: :charge_notifications

  comma do
    id
    name
    slug "url" do |slug| "https://hcb.hackclub.com/users/#{slug}/admin" end
    email
    transactions_missing_receipt_count "Missing Receipts"
  end

  SYSTEM_USER_EMAIL = "bank@hackclub.com"
  SYSTEM_USER_ID = 2891

  def self.system_user
    User.find(SYSTEM_USER_ID)
  end

  after_save do
    if use_sms_auth_previously_changed?
      if use_sms_auth
        create_activity(key: "user.enabled_sms_auth")
        User::SecurityMailer.security_configuration_changed(user: self, change: "SMS authentication was enabled").deliver_later
      else
        create_activity(key: "user.disabled_sms_auth")
        User::SecurityMailer.security_configuration_changed(user: self, change: "SMS authentication was disabled").deliver_later
      end
    end

    if use_two_factor_authentication_previously_changed?
      change = use_two_factor_authentication? ? "Two-factor authentication was enabled" : "Two-factor authentication was disabled"
      User::SecurityMailer.security_configuration_changed(user: self, change:).deliver_later
    end

    if phone_number_previously_changed? && phone_number.present?
      User::SecurityMailer.security_configuration_changed(user: self, change: "Phone number was changed to #{phone_number}").deliver_later
    end
  end

  scope :last_seen_within, ->(ago) { joins(:user_sessions).where(user_sessions: { impersonated_by_id: nil, last_seen_at: ago.. }).distinct }
  scope :currently_online, -> { last_seen_within(15.minutes.ago) }
  scope :active, -> { last_seen_within(30.days.ago) }
  scope :active_teenager, -> { last_seen_within(30.days.ago).where(teenager: true) }
  def active? = last_seen_at && (last_seen_at >= 30.days.ago)

  # a auditor is an admin who can only view things.
  # auditor? takes into account an admin user's preference
  # to pretend to be a non-admin, normal user
  def auditor?
    ["auditor", "admin", "superadmin"].include?(self.access_level) && !self.pretend_is_not_admin
  end

  # admin? by default, takes into account an admin user's preference
  # to pretend to be a non-admin, normal user
  def admin?(override_pretend: false)
    has_admin_role = ["admin", "superadmin"].include?(self.access_level)
    return has_admin_role if override_pretend

    has_admin_role && !self.pretend_is_not_admin
  end

  # admin_override_pretend? ignores an admin user's
  # preference to pretend not to be an admin.
  def admin_override_pretend?
    ["auditor", "admin", "superadmin"].include?(self.access_level)
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

  # gary@hackclub.com → g***y@hackclub.com
  # gt@hackclub.com → g*@hackclub.com
  # g@hackclub.com → g@hackclub.com
  def redacted_email
    handle, domain = email.split("@")
    redacted_handle =
      if handle.length <= 2
        handle[0] + "*" * (handle.length - 1)
      else
        "#{handle[0]}***#{handle[-1]}"
      end
    "#{redacted_handle}@#{domain}"
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
    # Invalidate all API tokens
    api_tokens.accessible.update_all(revoked_at: Time.current)
  end

  def unlock!
    update!(locked_at: nil)
  end

  def onboarding?
    # in_database to prevent a blank name update attempt from triggering onboarding.
    full_name_in_database.blank?
  end

  def was_onboarding?
    full_name_before_last_save.blank?
  end

  def active_mailbox_address
    self.mailbox_addresses.activated.first
  end

  def receipt_bin
    User::ReceiptBin.new(self)
  end

  def hcb_code_ids_missing_receipt
    @hcb_code_ids_missing_receipt ||= begin
      user_cards = stripe_cards.includes(event: :plan).where.not(plan: { type: Event::Plan::SalaryAccount.name }) + emburse_cards.includes(:emburse_transactions)
      user_cards.flat_map { |card| card.local_hcb_codes.missing_receipt.receipt_required.pluck(:id) }
    end
  end

  memo_wise def transactions_missing_receipt(from: nil, to: nil)
    return HcbCode.none unless hcb_code_ids_missing_receipt.any?

    user_hcb_codes = HcbCode.where(id: hcb_code_ids_missing_receipt)
    user_hcb_codes = user_hcb_codes.where("created_at >= ?", from) if from
    user_hcb_codes = user_hcb_codes.where("created_at <= ?", to) if to
    user_hcb_codes.order(created_at: :desc)
  end

  memo_wise def transactions_missing_receipt_count(from: nil, to: nil)
    transactions_missing_receipt(from:, to:).size
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

  def age_on(date)
    return unless birthday

    dob = birthday.to_date
    y = date.year

    # Safely handle leap years. Clamp the day to the number of days in dob.month for given year.
    day = [dob.day, Time.days_in_month(dob.month, y)].min
    bday_this_year = Date.new(y, dob.month, day)

    age = y - dob.year
    age -= 1 if date < bday_this_year
    age
  end

  def age
    age_on(Date.current)
  end

  def is_teenager?
    # Looks like funky syntax? Well, age may be nil, so there's a safe nav in there.
    age&.<=(18)
  end

  def was_teenager_on_join?
    age_on(created_at)&.<=(18)
  end

  def last_seen_at
    user_sessions.not_impersonated.maximum(:last_seen_at)
  end

  def last_login_at
    user_sessions.not_impersonated.maximum(:created_at)
  end

  def email_charge_notifications_enabled?
    charge_notifications_email? || charge_notifications_email_and_sms?
  end

  def sms_charge_notifications_enabled?
    charge_notifications_sms? || charge_notifications_email_and_sms?
  end

  def queue_sync_with_loops_job
    new_user = full_name_before_last_save.blank? && !onboarding?
    User::SyncUserToLoopsJob.perform_later(user_id: id, new_user:)
  end

  def only_card_grant_user?
    card_grants.size >= 1 && events.size == 0
  end

  def backup_codes_enabled?
    backup_codes.active.any?
  end

  def generate_backup_codes!
    backup_codes.previewed.destroy_all

    codes = []
    ActiveRecord::Base.transaction do
      while codes.size < 10
        code = SecureRandom.alphanumeric(10)
        next if codes.include?(code)

        backup_codes.create!(code: code)
        codes << code
      end
    end

    codes
  end

  def activate_backup_codes!
    ActiveRecord::Base.transaction do
      backup_codes.active.map(&:mark_discarded!)
      backup_codes.previewed.map(&:mark_active!)
    end
    User::BackupCodeMailer.with(user_id: id).new_codes_activated.deliver_now
  end

  def redeem_backup_code!(code)
    backup_codes.active.each do |backup_code|
      next unless backup_code.authenticate_code(code)

      ActiveRecord::Base.transaction do
        backup_code = User::BackupCode
                      .lock # performs a SELECT ... FOR UPDATE https://www.postgresql.org/docs/current/sql-select.html#SQL-FOR-UPDATE-SHARE
                      .active # makes sure that it hasn't already been used
                      .find(backup_code.id) # will raise `ActiveRecord::NotFound` and abort the transaction
        backup_code.mark_used!
        return true
      end
    end

    false
  end

  def disable_backup_codes!
    ActiveRecord::Base.transaction do
      backup_codes.previewed.destroy_all
      backup_codes.active.map(&:mark_discarded!)
    end
    BackupCodeMailer.with(user_id: id).backup_codes_disabled.deliver_now
  end

  def access_level_for(event, organizer_positions)
    role = nil
    access_level = nil
    user_ops = organizer_positions.select { |op| op.user == self }
    return nil if user_ops.empty?

    user_ops.each do |op|
      if role.nil? || OrganizerPosition.roles[op.role] > OrganizerPosition.roles[role]
        role = op.role
        access_level = op.event == event ? :direct : :indirect
      end
    end

    { role:, access_level: }
  end

  def needs_to_enable_2fa?
    admin_override_pretend? && !use_two_factor_authentication
  end

  def can_update_payout_method?
    return true if payout_method.nil?
    return true unless payout_method.is_a?(User::PayoutMethod::WiseTransfer)
    return false if reimbursement_reports.reimbursement_requested.any?
    return false if reimbursement_reports.joins(:payout_holding).where({ payout_holding: { aasm_state: :pending } }).any?

    true
  end

  def managed_active_teenagers_count
    User.active_teenager.joins(organizer_positions: :event).where(events: { id: managed_events }).distinct.count
  end

  # Total new teens via referrals links created by this user (admin)
  def new_teenagers_from_referrals_count
    self.referral_links.sum { |link| link.new_teenagers.size }
  end

  def has_discord_account?
    discord_id.present?
  end

  def discord_account
    return unless discord_id.present?

    @discord_bot ||= Discordrb::Bot.new token: Credentials.fetch(:DISCORD__BOT_TOKEN)

    @discord_account ||= @discord_bot.user(discord_id)
  end

  def only_draft_application?
    return false unless events.none? && card_grants.none? &&
                        organizer_position_invites.none? && contracts.none? &&
                        reimbursement_reports.none?

    apps = applications.limit(2).to_a

    apps.size == 1 && (apps.first.draft? || apps.first.submitted? || apps.first.under_review?)
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
    return if profile_picture.blob.content_type.start_with?("image/") && profile_picture.blob.variable?

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
    if payout_method_type_changed? && payout_method_type.present? && User::PayoutMethod::SUPPORTED_METHODS.none? { |method| payout_method.is_a?(method) }
      # I'm using `try` here in the slim chance that `payout_method` is some
      # random model and doesn't include `User::PayoutMethod::Shared`.
      if payout_method.try(:unsupported?)
        reason = payout_method.unsupported_details[:reason]
        errors.add(:payout_method, "is invalid. #{reason} Please choose another option.")
      else
        errors.add(:payout_method, "is invalid. Please choose another option.")
      end
    end

    if payout_method_type_changed? && payout_method.is_a?(User::PayoutMethod::WiseTransfer) && reimbursement_reports.where(aasm_state: %i[submitted reimbursement_requested reimbursement_approved]).any?
      errors.add(:payout_method, "cannot be changed to Wise transfer with reports that are being processed. Please reach out to the HCB team if you need this changed.")
    end
  end

  def second_factor_present_for_2fa
    if use_two_factor_authentication? && !use_sms_auth? && !totp.present? && webauthn_credentials.none?
      errors.add(:use_two_factor_authentication, "can not be enabled without a second authentication factor")
    end
  end

  def admins_cannot_disable_2fa
    return unless use_two_factor_authentication_changed?
    return if Rails.env.development?

    if needs_to_enable_2fa?
      errors.add(:use_two_factor_authentication, "cannot be disabled for admin accounts")
    end
  end

  def set_default_seasonal_theme
    return unless birthday_changed?
    # Skip if user ever updated their seasonal_themes_enabled setting
    return if versions.where_attribute_changes(:seasonal_themes_enabled).any?

    self.seasonal_themes_enabled = is_teenager?
  end

  def send_onboarded_email
    UserMailer.onboarded(user: self).deliver_later
  end

  def email_not_in_blacklisted_domains
    domain = email.split("@").last.downcase
    if BLACKLISTED_DOMAINS.include?(domain)
      errors.add(:email, "is invalid. Please use a different email address.")
    end
  end

end
