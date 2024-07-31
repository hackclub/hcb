# frozen_string_literal: true

# == Schema Information
#
# Table name: partner_donations
#
#  id                       :bigint           not null, primary key
#  aasm_state               :string
#  hcb_code                 :string
#  payout_amount_cents      :integer
#  stripe_charge_created_at :datetime
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  event_id                 :bigint           not null
#  stripe_charge_id         :string
#
# Indexes
#
#  index_partner_donations_on_event_id  (event_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
class PartnerDonation < ApplicationRecord
  has_paper_trail

  include AASM
  include Commentable

  include PublicIdentifiable
  set_public_id_prefix :pdn

  include HasStripeDashboardUrl
  has_stripe_dashboard_url "payments", :stripe_charge_id

  include PgSearch::Model
  pg_search_scope :search_name, against: [:hcb_code], using: { tsearch: { prefix: true, dictionary: "english" } }, ranked_by: "partner_donations.created_at"
  # @msw - ^ This only searches for hcb codes right now. regular donations
  # search by name and email because we have that info on our donors, but
  # partnered donations don't have those fields.
  # TODO: Add more fields to partnered_donations & check if we can fill name/email/phone from Stripe

  self.ignored_columns = ["donation_identifier"]

  belongs_to :event

  after_create :set_hcb_code

  scope :unpaid, -> { where(aasm_state: "unpaid") }
  scope :not_unpaid, -> { where.not(aasm_state: "unpaid") }
  scope :pending, -> { where(aasm_state: "pending") }
  scope :not_pending, -> { where.not(aasm_state: "pending") }
  scope :in_transit, -> { where(aasm_state: "in_transit") }
  scope :not_in_transit, -> { where.not(aasm_state: "in_transit") }
  scope :deposited, -> { where(aasm_state: "deposited") }
  scope :not_deposited, -> { where.not(aasm_state: "deposited") }

  aasm do
    state :unpaid, initial: true # once created (PaymentIntent most likely exists on Stripe), but might not be paid
    state :pending # Donation paid, but no payout created
    state :in_transit # when imported and marked as paid on Stripe::Charge
    state :deposited # when fully deposited to canonical transaction
    state :refunded # TODO: unimplemented at the moment!!! (there is no refund mechanism/detection)

    event :mark_pending do
      before do
        local_hcb_code # lazy create hcb code object
      end

      transitions from: :unpaid, to: :pending
    end

    event :mark_in_transit do
      transitions from: :pending, to: :in_transit
    end

    event :mark_deposited do
      transitions from: :in_transit, to: :deposited
    end
  end

  def smart_memo
    @smart_memo ||= donor_name
  end

  def donor_name
    remote_partner_donation.try(:[], :billing_details).try(:[], :name).to_s.upcase
  end

  def local_hcb_code
    @local_hcb_code ||= HcbCode.find_or_create_by(hcb_code:)
  end

  def paid?
    pending? || in_transit? || deposited? || stripe_charge_id.present?
  end

  def amount
    @amount ||= remote_partner_donation.try(:[], :amount).to_i
  end

  def partner
    Partner.find(event.partner_id)
  end

  def state
    aasm.current_state
  end

  def state_text
    case state
    when :pending
      "Pending"
    when :in_transit
      "In transit"
    when :deposited
      "Deposited"
    else
      "Unknown State"
    end
  end

  def state_icon
    case state
    when :pending
      "clock"
    when :in_transit
      "clock"
    when :deposited
      "checkmark"
    else
      "forbidden"
    end
  end

  def state_color
    case state
    when :pending
      "muted"
    when :in_transit
      "info"
    when :deposited
      "success"
    else
      "error"
    end
  end

  def payment_method_type
    stripe_obj[:payment_method_details][:type]
  rescue
    nil
  end

  def payment_method_card_brand
    stripe_obj[:payment_method_details][:card][:brand]
  rescue
    nil
  end

  def payment_method_card_last4
    stripe_obj[:payment_method_details][:card][:last4]
  rescue
    nil
  end

  def payment_method_card_funding
    stripe_obj[:payment_method_details][:card][:funding]
  rescue
    nil
  end

  def payment_method_card_exp_month
    stripe_obj[:payment_method_details][:card][:exp_month]
  rescue
    nil
  end

  def payment_method_card_exp_year
    stripe_obj[:payment_method_details][:card][:exp_year]
  rescue
    nil
  end

  def payment_method_card_country
    stripe_obj[:payment_method_details][:card][:country]
  rescue
    nil
  end

  def payment_method_card_checks_address_line1_check
    stripe_obj[:payment_method_details][:card][:checks][:address_line1_check]
  rescue
    nil
  end

  def payment_method_card_checks_address_postal_code_check
    stripe_obj[:payment_method_details][:card][:checks][:address_postal_code_check]
  rescue
    nil
  end

  def payment_method_card_checks_cvc_check
    stripe_obj[:payment_method_details][:card][:checks][:cvc_check]
  rescue
    nil
  end

  def canonical_pending_transaction
    canonical_pending_transactions.first
  end

  def canonical_transactions
    @canonical_transactions ||= CanonicalTransaction.where(hcb_code:)
  end

  def canonical_pending_transactions
    @canonical_pending_transactions ||= begin
      return [] unless raw_pending_partner_donation_transaction.present?

      ::CanonicalPendingTransaction.where(raw_pending_partner_donation_transaction_id: raw_pending_partner_donation_transaction.id)
    end
  end

  def stripe_obj
    remote_partner_donation
  end

  private

  def remote_partner_donation
    @remote_partner_donation ||=
      ::Partners::Stripe::Charges::Show.new(stripe_api_key: partner.stripe_api_key, id: stripe_charge_id).run.to_hash
  rescue => e
    {}
  end

  def raw_pending_partner_donation_transaction
    raw_pending_partner_donation_transactions.first
  end

  def raw_pending_partner_donation_transactions
    @raw_pending_partner_donation_transactions ||= ::RawPendingPartnerDonationTransaction.where(partner_donation_transaction_id: id)
  end

  def set_hcb_code
    self.update_column(:hcb_code, "HCB-#{::TransactionGroupingEngine::Calculate::HcbCode::PARTNER_DONATION_CODE}-#{id}")
  end

end
