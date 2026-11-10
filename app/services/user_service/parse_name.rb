# frozen_string_literal: true

module UserService
  # Splits a single-field full name into the first and last name stored on
  # `users.first_name` / `users.last_name`.
  #
  # Only used where a full name still arrives as one string: the backfill of
  # rows that predate the split columns, and legacy writers that assign
  # `User#full_name` directly. Everything else should set the two columns.
  #
  # Namae handles comma forms ("Doe, John"), particles ("Wernher von Braun")
  # and suffixes ("King Jr."). It also keeps a list of honorifics, and a
  # surname that collides with one ("Jane Elder", "Mary Lord") makes it either
  # give up entirely or treat the surname as a title. In those cases, and for
  # all-lowercase names it can't read, we fall back to a positional split so a
  # real surname is never lost.
  class ParseName
    Result = Struct.new(:first_name, :last_name, keyword_init: true)

    def initialize(full_name:)
      @full_name = full_name.to_s.squish
    end

    def run
      return Result.new(first_name: nil, last_name: nil) if @full_name.blank?

      parsed = Namae.parse(@full_name).first
      return positional_split if parsed.nil? || trailing_word_taken_as_title?(parsed) || given_name_taken_as_particle?(parsed)

      # Particles belong to the surname: "Juan de la Cruz" is "Juan" + "de la Cruz".
      first = parsed.given.presence
      last = [parsed.particle, parsed.family, parsed.suffix].compact_blank.join(" ").presence

      # "Madonna" parses as given-only; "Mr. Smith" parses as family-only.
      # Either way the one word we have belongs in first_name.
      first, last = last, nil if first.nil?

      Result.new(first_name: first, last_name: last)
    end

    private

    # Namae parsed "Jane W Elder" as given "Jane", family "W", title "Elder".
    # An honorific at the very end of a name is a surname, not a title.
    def trailing_word_taken_as_title?(parsed)
      parsed.title.present? && @full_name.downcase.end_with?(parsed.title.downcase)
    end

    # Namae reads leading lowercase words as particles, so "john smith" comes
    # back with no given name and "john" as a particle.
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
