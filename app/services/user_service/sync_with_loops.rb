# frozen_string_literal: true

module UserService
  class SyncWithLoops
    def initialize(user_id:, queue: Limiter::RateQueue.new(2, interval: 1), new_user: false)
      @user = User.find(user_id)
      @queue = queue
      @new_user = new_user
      @contact_details = contact_details
    end

    def run
      return if @user.onboarding?

      body = {
        email: @user.email,
        firstName: @user.first_name(legal: true),
        lastName: @user.last_name(legal: true),
        hcbSignedUpAt: format_unix(@user.created_at),
        birthday: format_unix(@user.birthday),
        hcbLastSeenAt: format_unix(@user.last_seen_at),
        hcbLastLoginAt: format_unix(@user.last_login_at),
        mailingLists: {
          # https://loops.so/docs/contacts/mailing-lists#api
          Rails.application.credentials.loops[:mailing_list_id] => true
        }
      }.compact_blank

      body[:userGroup] = @user.teenager? ? "Hack Clubber" : "HCB Adult"
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
      conn = Faraday.new(url: "https://app.loops.so/")

      resp = conn.send(:get) do |req|
        req.url("api/v1/contacts/find")
        req.headers["Authorization"] = "Bearer #{Rails.application.credentials.loops[:key]}"
        req.params[:email] = @user.email
      end

      return nil if resp.body.strip == "[]"

      JSON[resp.body][0]
    end

    def update(body:)
      @queue.shift
      conn = Faraday.new(url: "https://app.loops.so/")

      conn.send(:post) do |req|
        req.url("api/v1/contacts/update")
        req.body = body.to_json
        req.headers["Content-Type"] = "application/json"
        req.headers["Authorization"] = "Bearer #{Rails.application.credentials.loops[:key]}"
      end

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

  end
end
