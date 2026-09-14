# frozen_string_literal: true

require "rails_helper"

# Ledger::Item#cleanup_if_empty! destroys an otherwise-empty item, but only if
# none of its *other* associations have data — anything not explicitly listed
# in Ledger::Item::EMPTY_CHECK_IGNORED_ASSOCIATIONS blocks destruction by
# default (see Ledger::Item#blocking_associations). That fails closed for an
# association nobody's thought about yet, but it's still worth forcing a
# decision on every association explicitly, rather than letting one quietly
# sit in the "blocks by default" bucket forever.
#
# The list below is a baseline of the associations that existed when this
# safety net was introduced. It is a tripwire, not a certification that each
# entry's placement (ignored vs. blocking) was individually re-audited: its
# job is to force a decision on anything new.
#
# When this spec fails, decide whether the new association represents real
# data that would be silently lost if destruction proceeded (leave it out of
# EMPTY_CHECK_IGNORED_ASSOCIATIONS, so it blocks) or is safe to ignore (add it
# to EMPTY_CHECK_IGNORED_ASSOCIATIONS, with a comment explaining why). Either
# way, add it to the list below.
RSpec.describe "Ledger::Item associations coverage" do
  let(:reviewed_associations) do
    %i[
      all_ledgers
      author
      canonical_pending_transactions
      canonical_transactions
      comments
      hcb_code
      ledger_mappings
      linked_object
      primary_ledger
      primary_mapping
      receipts
      tags
      tasks
      versions
    ].freeze
  end

  it "has a decision recorded for every association" do
    Rails.application.eager_load!

    actual = Ledger::Item.reflect_on_all_associations.map(&:name).sort

    unreviewed = actual - reviewed_associations
    expect(unreviewed).to be_empty,
                          "New association(s) found on Ledger::Item. Decide whether they represent " \
                          "real data (leave them out of EMPTY_CHECK_IGNORED_ASSOCIATIONS, so they " \
                          "block destruction) or are safe to ignore (add them to " \
                          "EMPTY_CHECK_IGNORED_ASSOCIATIONS with a comment explaining why), then add " \
                          "them to reviewed_associations:\n  #{unreviewed.join("\n  ")}"

    stale = reviewed_associations - actual
    expect(stale).to be_empty,
                     "Stale entries in reviewed_associations; these associations no longer exist on " \
                     "Ledger::Item:\n  #{stale.join("\n  ")}"
  end
end
