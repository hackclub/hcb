# frozen_string_literal: true

module UserService
  class SyncWithLoops
    def initialize(user_id:, queue: Limiter::RateQueue.new(2, interval: 1), new_user: false)
      @user = User.includes(:events).find(user_id)
      @queue = queue
      @new_user = new_user
      @contact_details = contact_details
    end

    def run
      return if @user.onboarding?

      body = {
        email: @user.email,
        firstName: @user.first_name,
        lastName: @user.last_name,
        hcbSignedUpAt: format_unix(@user.created_at),
        birthday: format_unix(@user.birthday),
        hcbLastSeenAt: format_unix(@user.last_seen_at),
        hcbLastLoginAt: format_unix(@user.last_login_at),
        hcbHasActiveOrg: @user.events.active.any?,
        hcbHasCardGrant: @user.card_grants.any?,
        mailingLists: {
          # https://loops.so/docs/contacts/mailing-lists#api
          Credentials.fetch(:LOOPS, :MAILING_LIST) => true
        }
      }.compact_blank

      body[:userGroup] = @user.teenager? || @user.events.organized_by_teenagers.any? ? "Hack Clubber" : "HCB Adult"
      body[:subscribed] = true if @contact_details.nil?
      body[:source] = "HCB" if @contact_details.nil?

      body.merge!(billing_address)

      update(body:)
    end

    private

    def billing_address
      cardholder = @user.stripe_cardholder
      return {} if !cardholder || cardholder.default_billing_address? || (loops_has_address? && @contact_details["addressLastUpdatedAt"].present? && format_unix(cardholder.updated_at) < format_unix(Time.parse(@contact_details["addressLastUpdatedAt"])))

      {
        addressLine1: cardholder.address_line1,
        addressLine2: cardholder.address_line2,
        addressCity: cardholder.address_city,
        addressState: cardholder.address_state,
        addressZipCode: cardholder.address_postal_code,
        addressCountry: cardholder.address_country,
        addressLastUpdatedAt: format_unix(cardholder.updated_at)
      }.compact_blank
    end

    def contact_details
      @queue.shift

      # https://loops.so/docs/api-reference/find-contact
      resp = loops_client.get("api/v1/contacts/find", { email: @user.email })

      resp.body.first
    rescue Faraday::ResourceNotFound
      nil
    end

    def update(body:)
      @queue.shift

      # https://loops.so/docs/api-reference/update-contact
      loops_client.post("api/v1/contacts/update", body)
    end

    def format_unix(timestamp)
      timestamp&.to_datetime&.strftime("%Q")&.to_i # as milliseconds
    end

    def loops_has_address?
      # To consider a contact as having an address, it must have a line 1, city, and country present.
      # Some international addresses don't have the concept for states or zip codes.
      @contact_details&.[]("addressLine1").present? &&
        @contact_details["addressCity"].present? &&
        @contact_details["addressCountry"].present?
    end

    def loops_client
      @loops_client ||= Faraday.new(url: "https://loops.so/") do |c|
        c.request :authorization, "Bearer", -> { Credentials.fetch(:LOOPS) }
        c.request :json
        c.response :json
        c.response :raise_error
      end
    end

  end
end
