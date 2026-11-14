# frozen_string_literal: true

module UserService
  # Splits a legacy single-field full name into a first and last name.
  # Namae handles commas, particles and suffixes; anything it can't read is split positionally.
  class ParseName
    Result = Struct.new(:first_name, :last_name, keyword_init: true)

    # Credentials after a full name ("Jane Smith, PhD") aren't part of the legal name.
    TRAILING_CREDENTIAL = /\A(\S+ .+?),? (?:m\.?d|ph\.?d)\.?\z/i

    def initialize(full_name:)
      @full_name = full_name.to_s.squish.sub(TRAILING_CREDENTIAL, '\1')
    end

    def run
      return Result.new(first_name: nil, last_name: nil) if @full_name.blank?

      names = Namae.parse(@full_name)
      # Namae returns nothing for surnames on its title list, and several names for "John and Jane Doe".
      return positional_split unless names.one?

      parsed = names.first
      return positional_split if trailing_word_taken_as_title?(parsed) || given_name_taken_as_particle?(parsed)

      # Particles belong to the surname: "Juan de la Cruz" is "Juan" + "de la Cruz".
      first = parsed.given.presence
      last = [parsed.particle, parsed.family, parsed.suffix].compact_blank.join(" ").presence

      # A lone name ("Madonna", or "Smith" from "Mr. Smith") goes in first_name.
      first, last = last, nil if first.nil?

      Result.new(first_name: first, last_name: last)
    end

    private

    # "Jane W Elder" parses as given "Jane", family "W", title "Elder".
    def trailing_word_taken_as_title?(parsed)
      parsed.title.present? && @full_name.downcase.end_with?(parsed.title.downcase)
    end

    # "john smith" parses with no given name and "john" as a particle.
    def given_name_taken_as_particle?(parsed)
      parsed.given.blank? && parsed.particle.present?
    end

    def positional_split
      words = @full_name.split(" ")
      return Result.new(first_name: words.first, last_name: nil) if words.one?

      Result.new(first_name: words[0..-2].join(" "), last_name: words.last)
    end

  end
end
