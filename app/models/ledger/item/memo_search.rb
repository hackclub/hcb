# frozen_string_literal: true

class Ledger
  class Item
    # Turns a search box query into the words Ledger::Item.search_memo looks
    # for. Each word must appear somewhere in the memo, in any order, so a
    # partial word like "amaz" still finds "AMAZON MKTPLACE".
    module MemoSearch
      MAX_QUERY_LENGTH = 200
      # When the trigram index can't narrow a word down (e.g. one made mostly of
      # apostrophes, which become wildcards), every row is checked against the
      # pattern, and that cost grows with its length. Real memo words are rarely
      # past 30 characters, and a truncated word still matches as a substring.
      MAX_TOKEN_LENGTH = 40
      # A one-character word matches nearly every memo. Words under three
      # characters can't use the trigram index at all.
      MIN_TOKEN_LENGTH = 2

      # Zero-width spaces, soft hyphens, direction marks and the like.
      FORMAT_CHARACTERS = /\p{Cf}/
      # Includes NUL, which Postgres rejects in a query parameter.
      CONTROL_CHARACTERS = /\p{Cc}/
      # Straight and typographic double quotes. Phrases aren't supported, so a
      # quote only separates words.
      QUOTES = /["“”„«»]/
      # Phones type a curly apostrophe where memos usually have a straight one.
      APOSTROPHES = "'’‘ʼ"
      EDGE_PUNCTUATION = /\A[#{APOSTROPHES}.,;:!?()]+|[#{APOSTROPHES}.,;:!?()]+\z/

      module_function

      def tokens(query)
        words = query.to_s.scrub("")
                     .unicode_normalize(:nfkc) # e.g. non-breaking and full-width spaces become plain spaces
                     .first(MAX_QUERY_LENGTH)
                     .gsub(FORMAT_CHARACTERS, "")
                     .gsub(CONTROL_CHARACTERS, " ")
                     .gsub(QUOTES, " ")
                     .split(/[[:space:]]+/)
                     .map { |word| word.gsub(EDGE_PUNCTUATION, "").first(MAX_TOKEN_LENGTH) }
                     .select { |word| word.length >= MIN_TOKEN_LENGTH && word.match?(/[[:alnum:]]/) }
                     .uniq(&:downcase)

        # Every word must match, so a word contained in another adds nothing.
        words.reject { |word| words.any? { |other| other != word && other.downcase.include?(word.downcase) } }
      end

      # A substring ILIKE pattern for one token. LIKE metacharacters match
      # literally, and each apostrophe becomes a single-character wildcard so
      # "joe's" and "joe’s" find each other.
      def pattern(token)
        "%#{ActiveRecord::Base.sanitize_sql_like(token).gsub(/[#{APOSTROPHES}]/, "_")}%"
      end
    end

  end

end
