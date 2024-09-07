# frozen_string_literal: true

module StripeCardholderService
  class Create
    def initialize(current_user:, current_session:, event_id:)
      @current_user = current_user
      @current_session = current_session
      @event_id = event_id
    end

    def run
      raise ArgumentError, "not permitted under spend only plan" if event.unapproved?

      ActiveRecord::Base.transaction do
        stripe_cardholder = ::StripeCardholder.create!(attrs)

        remote_cardholder = ::StripeService::Issuing::Cardholder.create(remote_attrs)

        stripe_cardholder.update!(stripe_id: remote_cardholder.id)

        stripe_cardholder
      end
    end

    private

    def attrs
      {
        user: @current_user,
        stripe_name: name,
        stripe_email: email,
        stripe_phone_number: phone_number,
      }
    end

    def remote_attrs
      {
        name:,
        email:,
        phone_number:,
        type: cardholder_type,
        billing: {
          address: StripeCardholder::DEFAULT_BILLING_ADDRESS.compact
        },
        individual: {
          first_name: StripeCardholder.first_name(@current_user),
          last_name: StripeCardholder.last_name(@current_user),
          dob: DateOfBirthAgeRestrictedExtractor.new(user: @current_user).run,
          card_issuing: {
            user_terms_acceptance: {
              date: DateTime.now.to_i,
              ip: @current_session.ip
            }
          }
        }
      }
    end

    def email
      @current_user.email
    end

    def phone_number
      @current_user.phone_number
    end

    def name
      @current_user.safe_name
    end

    def cardholder_type
      "individual"
    end

    def event
      @event ||= Event.find(@event_id)
    end

  end
end
