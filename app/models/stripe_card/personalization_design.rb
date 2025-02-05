# frozen_string_literal: true

# == Schema Information
#
# Table name: stripe_card_personalization_designs
#
#  id                        :bigint           not null, primary key
#  common                    :boolean          default(FALSE), not null
#  stale                     :boolean          default(FALSE), not null
#  stripe_card_logo          :string
#  stripe_carrier_text       :jsonb
#  stripe_name               :string
#  stripe_status             :string
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  event_id                  :bigint
#  stripe_id                 :string
#  stripe_physical_bundle_id :string
#
# Indexes
#
#  index_stripe_card_personalization_designs_on_event_id  (event_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#
class StripeCard
  class PersonalizationDesign < ApplicationRecord
    has_paper_trail

    include HasStripeDashboardUrl
    has_stripe_dashboard_url "issuing/personalization-designs", :stripe_id

    include PgSearch::Model
    pg_search_scope :search, against: :stripe_name

    belongs_to :event, optional: true
    has_many :stripe_cards, foreign_key: "stripe_card_personalization_design_id", inverse_of: :personalization_design
    has_one_attached :logo
    validate :common_designs_must_not_belong_to_an_event

    scope :black, -> { where(stripe_physical_bundle_id: StripeService.physical_bundle_ids[:black]) }
    scope :white, -> { where(stripe_physical_bundle_id: StripeService.physical_bundle_ids[:white]) }

    scope :active, -> { where(stripe_status: "active") }
    scope :inactive, -> { where(stripe_status: "inactive") }
    scope :rejected, -> { where(stripe_status: "rejected") }
    scope :under_review, -> { where(stripe_status: "review") }

    scope :common, -> { where(common: true) }
    scope :not_common, -> { where(common: false) }
    scope :stale, -> { where(stale: true) }
    scope :live, -> { where(stale: false) }

    scope :available, -> { active.or(under_review).live }
    scope :unlisted, -> { where(event_id: nil, common: false) }

    alias_attribute :name, :stripe_name

    def sync_from_stripe!
      puts "syncing from stripe"
      self.stripe_id = stripe_obj[:id]
      self.stripe_status = stripe_obj[:status]
      if ["inactive", "rejected"].include?(stripe_status)
        self.stale = true
      end
      self.stripe_carrier_text = stripe_obj[:carrier_text]
      self.stripe_physical_bundle_id = stripe_obj[:physical_bundle]
      self.stripe_name = stripe_obj[:name]
      self.stripe_card_logo = stripe_obj[:card_logo]
      self.save
    end

    def color
      StripeService.physical_bundle_ids.invert[stripe_physical_bundle_id]
    end

    def black?
      color == :black
    end

    def white?
      color == :white
    end

    def active?
      stripe_status == "active"
    end

    def inactive?
      stripe_status == "inactive"
    end

    def rejected?
      stripe_status == "rejected"
    end

    def under_review?
      stripe_status == "review"
    end

    def unlisted?
      event_id.nil? && !common
    end

    def stripe_obj
      @stripe_obj ||= StripeService::Issuing::PersonalizationDesign.retrieve(stripe_id)
    end

    def common_designs_must_not_belong_to_an_event
      if event.present? && common
        errors.add(:event, "common designs must not belong to an event.")
      end
    end

    def name_without_id
      stripe_name&.sub(" (#{id})", "")
    end

  end

end
