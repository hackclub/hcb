# frozen_string_literal: true

require "rails_helper"

RSpec.describe AddressSuggestionService do
  describe ".search" do
    it "splits Mapbox's autocomplete hits into address fields, most relevant first" do
      stub_address_suggestions(letterman_drive_feature, oakfield_close_feature)

      suggestions = described_class.search("1 Letterman")

      expect(suggestions).to eq([
                                  {
                                    label: "1 Letterman Drive, San Francisco, California 94129, United States",
                                    line1: "1 Letterman Drive",
                                    city: "San Francisco",
                                    state_name: "California",
                                    state_code: "CA",
                                    postal_code: "94129",
                                    country: "US",
                                  },
                                  {
                                    label: "17 Oakfield Close, Sheffield, England S1 2AB, United Kingdom",
                                    line1: "17 Oakfield Close",
                                    city: "Sheffield",
                                    state_name: "England",
                                    state_code: "ENG",
                                    postal_code: "S1 2AB",
                                    country: "GB",
                                  },
                                ])
    end

    it "asks Mapbox for address autocompletions restricted to the given country" do
      stub_address_suggestions

      described_class.search("  1   Letterman ", country: "US")

      expect(Geocoder).to have_received(:search)
        .with("1 Letterman", params: { autocomplete: true, types: "address", limit: 5, language: "en", country: "us" })
    end

    it "ignores a country that is not a two-letter code" do
      stub_address_suggestions

      described_class.search("1 Letterman", country: "United States")

      expect(Geocoder).to have_received(:search)
        .with("1 Letterman", params: hash_not_including(:country))
    end

    it "does not query for fewer than three characters or a blank query" do
      stub_address_suggestions

      expect(described_class.search("1 ")).to eq([])
      expect(described_class.search(nil)).to eq([])
      expect(described_class.search("   ")).to eq([])
      expect(Geocoder).not_to have_received(:search)
    end

    it "truncates an overlong query" do
      stub_address_suggestions

      described_class.search("a" * 500)

      expect(Geocoder).to have_received(:search).with("a" * 120, params: anything)
    end

    it "builds the street line from the house number and street when there is no place name" do
      feature = letterman_drive_feature.merge("place_name" => nil)
      stub_address_suggestions(feature)

      expect(described_class.search("1 Letterman").first).to include(label: "", line1: "1 Letterman Drive")
    end

    it "falls back to the locality when a hit has no place" do
      feature = letterman_drive_feature
      feature["context"].reject! { |part| part["id"].start_with?("place.") }
      feature["context"] << { "id" => "locality.1", "text" => "Presidio" }
      stub_address_suggestions(feature)

      expect(described_class.search("1 Letterman").first).to include(city: "Presidio")
    end

    it "skips hits without a street line" do
      feature = letterman_drive_feature.merge("place_name" => nil, "address" => nil, "text" => nil)
      stub_address_suggestions(feature)

      expect(described_class.search("1 Letterman")).to eq([])
    end

    it "returns nothing when the geocoder fails" do
      allow(Geocoder).to receive(:search).and_raise(Geocoder::OverQueryLimitError)

      expect(described_class.search("1 Letterman")).to eq([])
    end
  end
end
