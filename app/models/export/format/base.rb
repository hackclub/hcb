# frozen_string_literal: true

class Export
  # Serializers from Export::Rows to a file format. Shared by every
  # transactions export so the columns, the formula escaping and what
  # transparency viewers may see are decided once.
  module Format
    class Base
      # The optional Export::Row fields this format shows. Every format shows
      # the date, memo and amount; an engine builds, and preloads for, only
      # what's listed here on top of those.
      READS = [].freeze

      def initialize(public_only:)
        @public_only = public_only
      end

      def reads?(field)
        self.class::READS.include?(field)
      end

      # How the format is called in a label, e.g. "CSV".
      def name = raise(NotImplementedError)
      def mime_type = raise(NotImplementedError)
      def extension = raise(NotImplementedError)

      # The file, from an Enumerable of Export::Rows.
      def content(rows) = raise(NotImplementedError)

      private

      attr_reader :public_only

      # Account-verification micro-deposits prove ownership of an external
      # account, so their amounts are redacted from transparency viewers.
      def visible_amount_cents(row)
        public_only && row.account_verification ? 0 : row.amount_cents
      end

      def visible_comments(row)
        public_only ? [] : row.comments
      end

    end
  end

end
