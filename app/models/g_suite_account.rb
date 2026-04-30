# frozen_string_literal: true

# == Schema Information
#
# Table name: g_suite_accounts
#
#  id                          :bigint           not null, primary key
#  accepted_at                 :datetime
#  address                     :text
#  backup_email                :text
#  first_name                  :string
#  initial_password_ciphertext :text
#  last_name                   :string
#  suspended_at                :datetime
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  creator_id                  :bigint
#  g_suite_id                  :bigint
#
# Indexes
#
#  index_g_suite_accounts_on_creator_id  (creator_id)
#  index_g_suite_accounts_on_g_suite_id  (g_suite_id)
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (g_suite_id => g_suites.id)
#
class GSuiteAccount < ApplicationRecord
  has_paper_trail skip: [:initial_password] # ciphertext columns will still be tracked
  has_encrypted :initial_password

  include Rejectable

  attr_accessor :skip_gsuite_sync

  after_update :attempt_notify_user_of_password_change

  paginates_per 50

  belongs_to :g_suite
  has_one :event, through: :g_suite
  has_many :g_suite_aliases, dependent: :destroy
  belongs_to :creator, class_name: "User"

  validates_presence_of :address, :backup_email, :first_name, :last_name
  normalizes :backup_email, with: ->(backup_email) { backup_email.strip.downcase }
  validates :backup_email, nondisposable: true, on: :create

  validate :status_accepted_or_rejected
  validate :within_quota, on: :create
  validates :address, uniqueness: { scope: :g_suite }

  before_update :sync_update_to_gsuite

  before_destroy :sync_delete_to_gsuite

  scope :under_review, -> { where(accepted_at: nil) }

  def status
    return "suspended" if suspended_at.present?
    return "accepted" if accepted_at.present?

    "pending"
  end

  def suspended?
    suspended_at.present?
  end

  def under_review?
    accepted_at.nil?
  end

  def username
    address.to_s.split("@").first
  end

  def at_domain
    "@#{address.to_s.split('@').last}"
  end

  def reset_password!
    unless Rails.env.production?
      puts "☣️ In production, we would currently be syncing the GSuite account password reset ☣️"
      return
    end

    # new 12-character password
    password = SecureRandom.hex(6)

    # ask GSuite to reset
    GsuiteService.instance.reset_gsuite_user_password(address, password)

    self.initial_password = password
    self.save
  end

  def toggle_suspension!
    if self.suspended_at.nil?
      self.suspended_at = DateTime.now
    else
      self.suspended_at = nil
    end

    self.save
  end

  # Engineer-only via Rails console. Removes this account from HCB
  # management, leaving the Google Workspace user (and its aliases) intact.
  # Intended for use in the Rails console when a user's account is being
  # transferred to the unmanaged hackclub.com domain from an HCB managed domain
  # (e.g., events.hackclub.com).
  def unmanage!(confirm:)
    raise ArgumentError, "confirm must match address" unless confirm == address

    # Materialize once so the in-memory `skip_gsuite_sync` we set below
    # survives — a later reload would drop the flag and re-trigger the
    # Google Workspace alias deletion callback.
    aliases = g_suite_aliases.reload.to_a

    Rails.logger.info(
      "[GSuiteAccount#unmanage!] unmanaging " \
      "id=#{id} address=#{address} g_suite_id=#{g_suite_id} " \
      "aliases=#{aliases.size}"
    )

    transaction do
      aliases.each do |gsa|
        gsa.skip_gsuite_sync = true
        gsa.destroy!
      end
      self.skip_gsuite_sync = true
      destroy!
    end
  end

  private

  def notify_user_of_password_change(first_password = false)
    email_params = {
      recipient: backup_email,
      address:,
      password: initial_password,
      event: g_suite.event.name,
    }

    creator_email_params = {
      recipient: creator.email,
      first_name:,
      last_name:,
      event: g_suite.event.name,
    }

    if first_password
      GSuiteAccountMailer.notify_user_of_activation(email_params).deliver_later
    else
      GSuiteAccountMailer.notify_user_of_reset(email_params).deliver_later
    end
  end

  def sync_delete_to_gsuite
    return if skip_gsuite_sync

    unless Rails.env.production?
      puts "☣️ In production, we would currently be syncing the GSuite account deletion ☣️"
      return
    end

    if !GsuiteService.instance.delete_gsuite_user(address)
      errors.add(:base, "couldn't be deleted from GSuite!")
      throw :abort
    end
  end

  def sync_update_to_gsuite
    return unless suspended_at_changed?

    unless Rails.env.production?
      puts "☣️ In production, we would currently be syncing the GSuite account suspension ☣️"
      return
    end

    if suspended_at.nil?
      GsuiteService.instance.toggle_gsuite_user_suspension(address, false)
    else
      GsuiteService.instance.toggle_gsuite_user_suspension(address, true)
    end
  end

  def attempt_notify_user_of_password_change
    return unless saved_change_to_initial_password?

    if initial_password.present?
      if initial_password_before_last_save.nil?
        notify_user_of_password_change(true)
      else
        notify_user_of_password_change
      end
    end
  end

  def within_quota
    return if g_suite.accounts.count < g_suite.max_accounts

    errors.add(:base, "You've reached your quota of #{g_suite.max_accounts} accounts and won't be able to create more accounts until you delete existing ones.")
  end

end
