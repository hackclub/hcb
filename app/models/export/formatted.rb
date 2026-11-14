# frozen_string_literal: true

class Export
  # The plumbing shared by every export that serializes Export::Rows through
  # an Export::Format. A subclass names its format as FORMAT, builds its
  # rows, and supplies a reader for each optional field (read_tags,
  # read_comments, ...); `fields_for` calls the readers for the fields the
  # format wants and no others.
  module Formatted
    extend ActiveSupport::Concern

    # The Export::Row fields a format may or may not read.
    OPTIONAL_FIELDS = %i[tags comments author category merchant].freeze

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

    # The optional fields the format reads, each through the engine's reader
    # for it, and no others.
    def fields_for(record)
      OPTIONAL_FIELDS.select { |field| reads?(field) }.index_with { |field| send(:"read_#{field}", record) }
    end

    # Only the organization's own tags; a transaction can be mapped into
    # several ledgers and carry another organization's tags alongside these.
    def own_tag_labels(tags)
      tags.select { |tag| tag.event_id == event_id.to_i }.map(&:label)
    end

    def non_admin_comments(comments)
      comments.reject(&:admin_only?).map(&:content)
    end

    def income_type(donation:, invoice:)
      if donation
        "Donation"
      elsif invoice
        "Invoice"
      else
        "Transfer"
      end
    end

  end

end
