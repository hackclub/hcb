# frozen_string_literal: true

# Geocoder loads result classes lazily with their lookups
require "geocoder/results/mapbox"

module AddressSuggestionSupport
  # A Mapbox Geocoding v5 address feature, as `Geocoder::Result::Mapbox#data`
  # returns it, trimmed to the parts `AddressSuggestionService` reads.
  def mapbox_address_feature(number:, street:, city:, region:, region_code:, postcode:, country:, country_code:)
    {
      "id"         => "address.#{[number, street].hash.abs}",
      "type"       => "Feature",
      "place_type" => ["address"],
      "relevance"  => 1,
      "properties" => { "accuracy" => "rooftop" },
      "text"       => street,
      "address"    => number,
      "place_name" => "#{number} #{street}, #{city}, #{region} #{postcode}, #{country}",
      "context"    => [
        { "id" => "postcode.1", "text" => postcode },
        { "id" => "place.1", "text" => city },
        { "id" => "region.1", "short_code" => region_code, "text" => region },
        { "id" => "country.1", "short_code" => country_code, "text" => country },
      ],
    }
  end

  def letterman_drive_feature
    mapbox_address_feature(number: "1", street: "Letterman Drive", city: "San Francisco", region: "California",
                           region_code: "US-CA", postcode: "94129", country: "United States", country_code: "us")
  end

  def oakfield_close_feature
    mapbox_address_feature(number: "17", street: "Oakfield Close", city: "Sheffield", region: "England",
                           region_code: "GB-ENG", postcode: "S1 2AB", country: "United Kingdom", country_code: "gb")
  end

  def stub_address_suggestions(*features, with: nil)
    results = features.map { |feature| Geocoder::Result::Mapbox.new(feature) }
    stub = allow(Geocoder).to receive(:search)
    stub = stub.with(*with) if with
    stub.and_return(results)
  end
end

RSpec.configure do |config|
  config.include AddressSuggestionSupport
end
