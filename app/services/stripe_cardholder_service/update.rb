# frozen_string_literal: true

module StripeCardholderService
  class Update
    def initialize(current_user:)
      @current_user = current_user
    end

    def run
      ActiveRecord::Base.transaction do
        stripe_cardholder = ::StripeCardholder.find_by(user_id: @current_user.id)
        ::StripeService::Issuing::Cardholder.update(stripe_cardholder.stripe_id, remote_params) unless stripe_cardholder.nil?
      end
    end

    private

    def remote_params
      {
        individual: {
          dob: DateOfBirthAgeRestrictedExtractor.new(user: @current_user).run,
          first_name:,
          last_name:
        }
      }
    end

    def first_name
      clean_name(@current_user.first_name(legal: true))
    end

    def last_name
      clean_name(@current_user.last_name(legal: true))
    end

    def clean_name(name)
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

  end
end
