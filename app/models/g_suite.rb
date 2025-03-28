# frozen_string_literal: true

# == Schema Information
#
# Table name: g_suites
#
#  id                   :bigint           not null, primary key
#  aasm_state           :string           default("creating")
#  deleted_at           :datetime
#  dkim_key             :text
#  domain               :citext
#  remote_org_unit_path :text
#  verification_key     :text
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  created_by_id        :bigint
#  event_id             :bigint
#  remote_org_unit_id   :text
#
# Indexes
#
#  index_g_suites_on_created_by_id  (created_by_id)
#  index_g_suites_on_event_id       (event_id)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (event_id => events.id)
#
class GSuite < ApplicationRecord
  VALID_DOMAIN = /\A[a-z0-9]+([-.]{1}[a-z0-9]+)*\.[a-z]{2,24}(:[0-9]{1,5})?(\/.*)?\z/ix

  acts_as_paranoid
  validates_as_paranoid
  has_paper_trail

  include PgSearch::Model
  pg_search_scope :search_domain, against: [:domain, :event_id], using: { tsearch: { prefix: true, dictionary: "english" } }

  include AASM
  include Commentable

  belongs_to :event
  belongs_to :created_by, class_name: "User", optional: true
  has_many :accounts, class_name: "GSuiteAccount"

  aasm do
    state :creating, initial: true
    state :configuring
    state :verifying
    state :verification_error
    state :verified

    event :mark_creating do
      transitions to: :creating
    end

    event :mark_configuring do
      transitions to: :configuring
    end

    event :mark_verifying do
      transitions from: [:configuring, :verification_error], to: :verifying
    end

    event :mark_verification_error do
      after do
        if aasm.from_state == :verified
          GSuiteMailer.with(g_suite_id: self.id).notify_of_error_after_verified.deliver_later
        else
          GSuiteMailer.with(g_suite_id: self.id).notify_of_verification_error.deliver_later
        end
      end
      transitions from: [:verifying, :verified], to: :verification_error
    end

    event :mark_verified do
      transitions from: [:verifying], to: :verified
    end

  end

  scope :needs_ops_review, -> { where(aasm_state: ["creating", "verifying"]) }

  validates :domain, presence: true, format: { with: VALID_DOMAIN }
  validates_uniqueness_of_without_deleted :domain

  before_validation :clean_up_verification_key

  def needs_ops_review?
    @needs_ops_review ||= creating? || verifying?
  end

  def verified_on_google?
    @verified_on_google ||= ::Partners::Google::GSuite::Domain.new(domain:).run.verified
  rescue => e
    Rails.error.report(e)

    false
  end

  def verification_url
    "https://www.google.com/webmasters/verification/verification?siteUrl=http://#{domain}&priorities=vdns,vmeta,vfile,vanalytics"
  end

  def dns_check_url
    "https://nslookup.io/dns-records/#{domain}"
  end

  def subdomain
    domain.split(".")[0..-3].join(".").presence
  end

  def previously_verified?
    versions.where_object_changes_to(aasm_state: "verified").any?
  end

  private

  def clean_up_verification_key
    self.verification_key = verification_key.gsub("google-site-verification=", "") if verification_key.present?
  end

end
