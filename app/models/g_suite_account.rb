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

  after_update :attempt_notify_user_of_password_change

  paginates_per 50

  belongs_to :g_suite
  has_one :event, through: :g_suite
  belongs_to :creator, class_name: "User"

  validates_presence_of :address, :backup_email, :first_name, :last_name

  validate :status_accepted_or_rejected
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

end
