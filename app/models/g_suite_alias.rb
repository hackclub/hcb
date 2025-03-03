# frozen_string_literal: true

# == Schema Information
#
# Table name: g_suite_aliases
#
#  id                 :bigint           not null, primary key
#  address            :text
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  g_suite_account_id :bigint           not null
#
# Indexes
#
#  index_g_suite_aliases_on_g_suite_account_id  (g_suite_account_id)
#
# Foreign Keys
#
#  fk_rails_...  (g_suite_account_id => g_suite_accounts.id)
#
class GSuiteAlias < ApplicationRecord
  belongs_to :g_suite_account
  has_one :g_suite, through: :g_suite_account

  validates :address, uniqueness: { case_sensitive: false }, presence: true
  validate :fewer_than_max_aliases, on: :create
  validate :address_unique_against_accounts

  before_create do
    create_alias_with_google
  end

  before_destroy do
    delete_alias_with_google
  end

  def username
    address.to_s.split("@").first
  end

  def at_domain
    "@#{address.to_s.split('@').last}"
  end

  private

  def create_alias_with_google
    Partners::Google::GSuite::CreateUserAlias.new(primary_email: g_suite_account.address, alias_email: address).run
  end

  def delete_alias_with_google
    Partners::Google::GSuite::DeleteUserAlias.new(primary_email: g_suite_account.address, alias_email: address).run
  end

  def fewer_than_max_aliases
    if g_suite_account.g_suite_aliases.count >= 30
      errors.add(:base, "You may only have 30 Google Workspace aliases per email. Please remove an alias before creating a new one.")
    end
  end

  def address_unique_against_accounts
    if g_suite.accounts.where(address:).exists?
      errors.add(:base, "An account already exists with this email address.")
    end
  end

end
