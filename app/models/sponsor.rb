# frozen_string_literal: true

# == Schema Information
#
# Table name: sponsors
#
#  id                  :bigint           not null, primary key
#  address_city        :text
#  address_country     :text             default("US")
#  address_line1       :text
#  address_line2       :text
#  address_postal_code :text
#  address_state       :text
#  contact_email       :text
#  name                :text
#  slug                :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  event_id            :bigint
#  stripe_customer_id  :text
#
# Indexes
#
#  index_sponsors_on_event_id  (event_id)
#  index_sponsors_on_slug      (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
class Sponsor < ApplicationRecord
  has_paper_trail

  include PublicIdentifiable
  set_public_id_prefix :spr

  include HasStripeDashboardUrl
  has_stripe_dashboard_url "customers", :stripe_customer_id

  extend FriendlyId

  include PgSearch::Model
  pg_search_scope :search_name, against: [:name, :contact_email]

  scope :not_null_slugs, -> { where.not(slug: nil) }

  friendly_id :slug_candidates, use: :slugged

  belongs_to :event
  has_many :invoices

  validates_presence_of :name, :contact_email, :address_line1, :address_city,
                        :address_state, :address_postal_code

  before_create :create_stripe_customer
  before_update :update_stripe_customer
  before_destroy :destroy_invoices
  before_destroy :destroy_stripe_customer

  normalizes :contact_email, with: ->(contact_email) { contact_email.strip.downcase }

  def status
    i = invoices.last
    if i.nil?
      :muted
    elsif i.paid_v2?
      :success
    elsif i.due_date < Time.current
      :error
    elsif i.due_date < 3.days.from_now
      :warning
    else
      :muted
    end
  end

  def status_description
    i = invoices.last
    if i.nil?
      "No invoices yet"
    elsif i.paid_v2?
      "Last invoice paid"
    elsif i.due_date < Time.current
      "Last invoice overdue + unpaid"
    elsif i.due_date < 5.days.from_now
      "Last invoice due soon"
    else
      "Last invoice due further out"
    end
  end

  def create_stripe_customer
    cu = StripeService::Customer.create(stripe_params)
    self.stripe_customer_id = cu.id
  end

  def update_stripe_customer
    cu = StripeService::Customer.retrieve(self.stripe_customer_id)

    stripe_params.each do |k, v|
      cu.send("#{k}=", v)
    end

    cu.save
  end

  def destroy_stripe_customer
    cu = StripeService::Customer.retrieve(self.stripe_customer_id)
    cu.delete
  end

  def destroy_invoices
    self.invoices.destroy_all
  end

  private

  def stripe_params
    {
      description: self.name,
      email: self.contact_email,
      shipping: {
        name: self.name,
        address: {
          line1: self.address_line1,
          line2: self.address_line2,
          city: self.address_city,
          state: self.address_state,
          postal_code: self.address_postal_code,
          country: self.address_country
        }
      }
    }
  end

  def slug_candidates
    [
      :name,
      [:name, -> { self.event.name }]
    ]
  end

end
