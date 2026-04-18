# frozen_string_literal: true

require "namae"

module UserService
  # Parses a full name into first and last name components using the Namae gem.
  # Handles complex names with particles (von, de, etc.) and suffixes (Jr., Sr., III, etc.)
  class ParseName
    attr_reader :given_name, :particle, :family_name, :suffix

    def initialize(full_name:)
      @full_name = full_name
      @given_name = nil
      @particle = nil
      @family_name = nil
      @suffix = nil
    end

    # Parse the full name and extract components
    def run
      return self if @full_name.blank?

      parsed = Namae.parse(@full_name).first
      return self if parsed.nil?

      @given_name = parsed.given
      @particle = parsed.particle
      @family_name = parsed.family
      @suffix = parsed.suffix

      self
    end

    # Returns the formatted first name (given name + particle if present).
    # Stores what should go in the database first_name column.
    # Example: "Wernher von" for "Wernher von Braun"
    def first_name
      return nil if @given_name.nil? && @family_name.nil?

      parts = [@given_name, @particle].compact_blank
      return @family_name if parts.empty?

      parts.join(" ").presence
    end

    # Returns the formatted last name (family name + suffix if present).
    # Stores what should go in the database last_name column.
    # Example: "King Jr." for "Martin Luther King Jr."
    def last_name
      parts = [@family_name, @suffix].compact_blank
      parts.empty? ? nil : parts.join(" ").presence
    end


  end
end
