# frozen_string_literal: true

# == Schema Information
#
# Table name: event_applications
#
#  id                    :bigint           not null, primary key
#  aasm_state            :string
#  address_city          :string
#  address_country       :string
#  address_line1         :string
#  address_line2         :string
#  address_postal_code   :string
#  address_state         :string
#  airtable_status       :string
#  cosigner_email        :string
#  description           :text
#  name                  :string
#  notes                 :text
#  political_description :text
#  referral_code         :string
#  referrer              :string
#  website_url           :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  airtable_record_id    :string
#  event_id              :bigint
#  user_id               :bigint           not null
#
# Indexes
#
#  index_event_applications_on_event_id  (event_id)
#  index_event_applications_on_user_id   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (user_id => users.id)
#
class Event
  class Application < ApplicationRecord
    include AASM

    APPLICATION_STEPS = [:project_info, :personal_info].freeze

    belongs_to :user, optional: false
    belongs_to :event, optional: true

    aasm do
      state :draft, initial: true
      state :submitted
      state :under_review
      state :approved
      state :rejected

      event :mark_submitted do
        transitions from: :draft, to: :submitted
      end
    end

    def next_step
      return "Tell us about your project" if name.blank? || description.blank?
      return "Add your information" if address_line1.blank? || address_city.blank? || address_country.blank? || address_postal_code.blank?
      return "Review and submit" if draft?
    end

    def status_color
      return :muted if draft?
      return :blue if submitted?
      return :purple if under_review?
      return :green if approved?
      return :red if rejected?

      :muted
    end

    def completion_percentage
      return 25 if next_step == "Tell us about your project"
      return 50 if next_step == "Add your information"
      return 75 if next_step == "Review and submit"
      return 100 if submitted?

      0
    end

    def political?
      political_description.present? && political_description.strip.length.positive?
    end

  end

end
