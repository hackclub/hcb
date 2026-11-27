# frozen_string_literal: true

# Street address suggestions for the `address-autocomplete` Stimulus
# controller. Queries Mapbox's geocoder in autocomplete mode through the
# `Geocoder` gem (configured in config/initializers/geocoder.rb, which also
# caches responses) and splits each hit into the fields an address form has.
module AddressSuggestionService
  MIN_QUERY_LENGTH = 3
  MAX_QUERY_LENGTH = 120
  LIMIT = 5

  # @param query [String, nil] what the user has typed into the street address field
  # @param country [String, nil] ISO 3166-1 alpha-2 code to restrict results to
  # @return [Array<Hash>] up to LIMIT suggestions, most relevant first
  def self.search(query, country: nil)
    query = query.to_s.squish.first(MAX_QUERY_LENGTH)
    return [] if query.length < MIN_QUERY_LENGTH

    params = { autocomplete: true, types: "address", limit: LIMIT, language: "en" }
    params[:country] = country.downcase if country.to_s.match?(/\A[A-Za-z]{2}\z/)

    Geocoder.search(query, params:).filter_map { |result| suggestion(result.data) }
  rescue Geocoder::Error, Timeout::Error, SocketError, SystemCallError => e
    Rails.logger.warn("AddressSuggestionService: #{e.class}: #{e.message}")
    []
  end

  # @param feature [Hash] a Mapbox Geocoding v5 feature
  def self.suggestion(feature)
    place_name = feature["place_name"].to_s
    # Mapbox orders the house number and street the way the country does
    # (`17 Oakfield Close` vs `Hauptstraße 5`), so take its first segment.
    line1 = place_name.split(",").first.to_s.strip
    line1 = [feature["address"], feature["text"]].compact_blank.join(" ") if line1.blank?
    return if line1.blank?

    {
      label: place_name,
      line1:,
      city: context_part(feature, "place") || context_part(feature, "locality") || context_part(feature, "district"),
      state_name: context_part(feature, "region"),
      state_code: context_part(feature, "region", "short_code")&.split("-")&.last&.upcase,
      postal_code: context_part(feature, "postcode"),
      country: context_part(feature, "country", "short_code")&.upcase,
    }
  end

  def self.context_part(feature, name, key = "text")
    Array(feature["context"]).find { |part| part["id"].to_s.start_with?("#{name}.") }&.dig(key).presence
  end

  private_class_method :suggestion, :context_part
end
