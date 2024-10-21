# frozen_string_literal: true

module SearchService
  class Formatter
    include UsersHelper
    def initialize(results)
      @results = results
    end

    def run
      @results.map { |x| format(x) }
    end

    private

    def format(item)

      formatted = {
        label: item["last4"] || item["custom_memo"] || item["memo"] || item["name"] || item["full_name"] || "Unknown",
        type: item.class,
      }

      if item.instance_of?(Event) && item.logo.attached?
        formatted[:image] = Rails.application.routes.url_helpers.url_for(item.logo)
      end

      if item.instance_of?(CanonicalTransaction) && item.transaction_source_type == "RawStripeTransaction"
        formatted[:user] = item.stripe_cardholder&.user&.name
      end

      if item.instance_of?(CanonicalTransaction)
        formatted[:event] = item&.event&.name
        formatted[:path] = "/hcb/#{item.hcb_code}"
        formatted[:amount_cents] = item.amount_cents
      end

      if item.instance_of?(StripeCard)
        formatted[:event] = item&.event&.name
        formatted[:user] = item.stripe_cardholder.user.name
        formatted[:path] = "/stripe_cards/#{item.hashid}"
      end

      if item.instance_of?(Event)
        formatted[:balance] = item.balance
        formatted[:path] = "/#{item.slug}"
      end

      if item.instance_of?(User)
        formatted[:label] = item.name
        formatted[:path] = "/users/#{item.slug}/edit"
        formatted[:image] = profile_picture_for(item)
      end

      if item.instance_of?(Reimbursement::Report)
        formatted[:path] = "/reimbursement/reports/#{item.hashid}/"
        formatted[:user] = item.user.name
        formatted[:event] = item&.event&.name
      end

      formatted

    end

  end
end
