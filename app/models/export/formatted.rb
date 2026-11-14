# frozen_string_literal: true

class Export
  # The plumbing shared by every export that serializes Export::Rows through
  # an Export::Format. A subclass names its format as FORMAT and builds its
  # rows, consulting `reads?` for which optional fields the format wants;
  # the rest follows.
  module Formatted
    extend ActiveSupport::Concern

    included do
      delegate :mime_type, to: :formatter
      delegate :reads?, to: :formatter, private: true
    end

    def content
      formatter.content(rows)
    end

    private

    def formatter
      @formatter ||= self.class::FORMAT.new(public_only: public_only == true)
    end

    # The Export::Rows to serialize.
    def rows = raise(NotImplementedError)

  end

end
