# frozen_string_literal: true

# == Schema Information
#
# Table name: stripe_cardholders
#
#  id                                 :bigint           not null, primary key
#  cardholder_type                    :integer          default("individual"), not null
#  stripe_billing_address_city        :text
#  stripe_billing_address_country     :text
#  stripe_billing_address_line1       :text
#  stripe_billing_address_line2       :text
#  stripe_billing_address_postal_code :text
#  stripe_billing_address_state       :text
#  stripe_email                       :text
#  stripe_name                        :text
#  stripe_phone_number                :text
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  stripe_id                          :text
#  user_id                            :bigint           not null
#
# Indexes
#
#  index_stripe_cardholders_on_stripe_id  (stripe_id)
#  index_stripe_cardholders_on_user_id    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class StripeCardholder < ApplicationRecord
  include HasStripeDashboardUrl
  has_stripe_dashboard_url "issuing/cardholders", :stripe_id

  enum :cardholder_type, { individual: 0, company: 1 }

  belongs_to :user
  has_many :stripe_cards
  alias_method :cards, :stripe_cards
  has_many :stripe_authorizations, through: :stripe_cards
  alias_method :authorizations, :stripe_authorizations
  alias_method :transactions, :stripe_authorizations

  validates_uniqueness_of :stripe_id

  validates :stripe_billing_address_line1, presence: true, on: :update
  validates :stripe_billing_address_city, presence: true, on: :update
  validates :stripe_billing_address_country, presence: true, on: :update

  validates_comparison_of :stripe_billing_address_country, equal_to: "US"
  validates :stripe_billing_address_state, inclusion: {
    in: ->(cardholder) { ISO3166::Country[cardholder.stripe_billing_address_country].subdivisions.keys },
    message: ->(cardholder, data) { "is not a state/province in #{ISO3166::Country[cardholder.stripe_billing_address_country].common_name}" },
  }, if: -> { stripe_billing_address_country.present? }

  alias_attribute :address_line1, :stripe_billing_address_line1
  alias_attribute :address_line2, :stripe_billing_address_line2
  alias_attribute :address_city, :stripe_billing_address_city
  alias_attribute :address_state, :stripe_billing_address_state
  alias_attribute :address_country, :stripe_billing_address_country
  alias_attribute :address_postal_code, :stripe_billing_address_postal_code

  after_validation :update_cardholder_in_stripe, on: :update, if: -> { errors.none? }

  before_validation :set_default_billing_address

  def state
    return :success if remote_status == "active"
    return :error if remote_status == "blocked"
    return :error if remote_status == "disabled"

    :muted
  end

  def state_text
    remote_status.to_s.humanize
  end

  def full_address
    [
      stripe_billing_address_line1,
      stripe_billing_address_line2,
      stripe_billing_address_city,
      stripe_billing_address_state,
      stripe_billing_address_postal_code
    ].join(" ")
  end

  def remote_status
    return "disabled" if remote_requirements_disabled_reason.present?

    stripe_obj[:status]
  end

  def remote_requirements_disabled_reason
    stripe_obj[:requirements].try(:[], :disabled_reason)
  end

  DEFAULT_BILLING_ADDRESS = {
    line1: "8605 Santa Monica Blvd #86294",
    line2: nil,
    city: "West Hollywood",
    state: "CA",
    postal_code: "90069",
    country: "US"
  }.freeze

  def default_billing_address?
    DEFAULT_BILLING_ADDRESS.all? do |key, value|
      self.public_send(:"address_#{key}") == value
    end
  end

  def self.first_name(user)
    clean_name(user.first_name(legal: true))
  end

  def self.last_name(user)
    clean_name(user.last_name(legal: true))
  end

  def self.clean_name(name)
    name = ActiveSupport::Inflector.transliterate(name || "")

    # Remove invalid characters
    requirements = <<~REQ.squish
      First and Last names must contain at least 1 letter, and may not
      contain any numbers, non-latin letters, or special characters except
      periods, commas, hyphens, spaces, and apostrophes.
    REQ
    name = name.gsub(/[^a-zA-Z.,\-\s']/, "").strip
    raise ArgumentError, requirements if name.gsub(/[^a-z]/i, "").blank?

    name
  end

  private

  def set_default_billing_address
    DEFAULT_BILLING_ADDRESS.each do |key, value|
      method = :"address_#{key}"
      self.public_send(:"#{method}=", value) if self.public_send(method).blank?
    end
  end

  def update_cardholder_in_stripe
    StripeService::Issuing::Cardholder.update(
      stripe_id,
      {
        email: stripe_email,
        phone_number: stripe_phone_number,
        billing: {
          address: {
            line1: address_line1,
            line2: address_line2,
            city: address_city,
            state: address_state,
            postal_code: address_postal_code,
            country: address_country
          }.compact_blank
        }
      }.compact_blank # Stripe doesn't like blank values
    )
  rescue Stripe::StripeError => error
    if error.message.downcase.include?("address") || error.message.downcase.include?("country") || error.message.downcase.include?("state")
      errors.add(:base, error.message)
    else
      raise if Rails.env.production? # update fails without proper keys
    end
  end

  def stripe_obj
    @stripe_obj ||= StripeService::Issuing::Cardholder.retrieve(stripe_id)
  rescue => e
    Rails.error.report(e)

    { status: "active", requirements: {} } # https://stripe.com/docs/api/issuing/cardholders/object
  end

end
