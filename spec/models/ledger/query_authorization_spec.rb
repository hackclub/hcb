# frozen_string_literal: true

require "rails_helper"

# Filtering on a field is a read of that field: a query returning only the rows
# whose memo matches discloses those memos, and `{ author: ... }` enumerates one
# person's transactions whether or not the author is rendered. These assert that
# a caller cannot filter on a column it could not have read.
RSpec.describe Ledger::Query, "column authorization" do
  let(:transparent) { create(:event, :with_positive_balance, is_public: true) }
  let(:private_org) { create(:event, :with_positive_balance, is_public: false) }

  def run(query, viewer:, ledgers:)
    described_class.new(query, viewer:).execute(ledgers:)
  end

  context "on a private organization" do
    let(:ledger) { private_org.ledger }

    it "refuses every column to someone who cannot read the organization" do
      expect { run({ memo: "x" }, viewer: nil, ledgers: [ledger]) }
        .to raise_error(Ledger::Query::NotAuthorized, /memo/)
    end

    it "refuses a column an outsider cannot see even when the value is harmless" do
      expect { run({ amount_cents: 0 }, viewer: create(:user), ledgers: [ledger]) }
        .to raise_error(Ledger::Query::NotAuthorized)
    end

    it "allows a reader to filter on public-tier columns" do
      reader = create(:user)
      create(:organizer_position, user: reader, event: private_org, role: :reader)

      expect { run({ memo: "x" }, viewer: reader, ledgers: [ledger]) }.not_to raise_error
    end
  end

  context "on a transparent organization" do
    let(:ledger) { transparent.ledger }

    it "allows an anonymous caller to filter on public-tier columns" do
      expect { run({ amount_cents: { "$gt": 100 } }, viewer: nil, ledgers: [ledger]) }.not_to raise_error
    end

    # `lost_receipt` is organizer-only in Ledger::ItemPolicy, so the column that
    # discloses it must be too — this is the case the old fixed
    # PERMITTED_COLUMNS_MAP could not express.
    it "refuses a column whose attribute is organizer-only" do
      expect { run({ marked_no_or_lost_receipt_at: nil }, viewer: nil, ledgers: [ledger]) }
        .to raise_error(Ledger::Query::NotAuthorized, /marked_no_or_lost_receipt_at/)
    end

    it "allows an organizer that same column" do
      organizer = create(:user)
      create(:organizer_position, user: organizer, event: transparent, role: :reader)

      expect { run({ marked_no_or_lost_receipt_at: nil }, viewer: organizer, ledgers: [ledger]) }.not_to raise_error
    end
  end

  it "holds a multi-ledger query to the most restrictive ledger" do
    reader = create(:user)
    create(:organizer_position, user: reader, event: transparent, role: :reader)

    # Readable on the transparent ledger, not on the private one.
    expect { run({ marked_no_or_lost_receipt_at: nil }, viewer: reader, ledgers: [transparent.ledger, private_org.ledger]) }
      .to raise_error(Ledger::Query::NotAuthorized)
  end

  it "checks columns nested inside logical operators" do
    expect {
      run({ "$or": [{ amount_cents: 1 }, { "$and": [{ marked_no_or_lost_receipt_at: nil }] }] },
          viewer: nil, ledgers: [transparent.ledger])
    }.to raise_error(Ledger::Query::NotAuthorized, /marked_no_or_lost_receipt_at/)
  end

  # v3's transaction entity exposes the author outside `when_expanded`, so it is
  # already published on a transparent organization. Filtering by it therefore
  # discloses nothing a caller could not page through and read — but the same
  # filter on a private organization must still be refused.
  it "allows filtering by author on a transparent organization, matching v3" do
    expect { run({ author: "someone" }, viewer: nil, ledgers: [transparent.ledger]) }.not_to raise_error
  end

  it "refuses filtering by author on a private organization" do
    expect { run({ author: "someone" }, viewer: nil, ledgers: [private_org.ledger]) }
      .to raise_error(Ledger::Query::NotAuthorized, /author/)
  end

  it "lets an empty query through" do
    expect { run({}, viewer: nil, ledgers: [transparent.ledger]) }.not_to raise_error
  end

  it "skips the check for :trusted internal callers" do
    expect { run({ marked_no_or_lost_receipt_at: nil }, viewer: :trusted, ledgers: [private_org.ledger]) }
      .not_to raise_error
  end

  it "requires a viewer rather than defaulting to one" do
    expect { described_class.new({}) }.to raise_error(ArgumentError, /viewer/)
  end

end
