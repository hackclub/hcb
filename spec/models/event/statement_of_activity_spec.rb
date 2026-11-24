# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event::StatementOfActivity do
  describe "#start_date" do
    it "parses the param value if one is provided" do
      event = create(:event)
      instance = described_class.new(event, start_date_param: "2025-01-01")

      expect(instance.start_date).to eq(Date.new(2025, 1, 1))
    end

    it "falls back to the event activation date" do
      event = create(:event, activated_at: Time.new(2025, 1, 1))
      instance = described_class.new(event)

      expect(instance.start_date).to eq(Date.new(2025, 1, 1))
    end

    it "falls back to the event creation date" do
      event = create(:event, created_at: Time.new(2025, 1, 1))
      instance = described_class.new(event)

      expect(instance.start_date).to eq(Date.new(2025, 1, 1))
    end

    it "picks the oldest creation date when dealing with a group" do
      group = create(:event_group)

      event1 = create(:event, created_at: Time.new(2025, 1, 1))
      group.memberships.create!(event: event1)

      event2 = create(:event, created_at: Time.new(2024, 1, 1))
      group.memberships.create!(event: event2)

      instance = described_class.new(group)

      expect(instance.start_date).to eq(Date.new(2024, 1, 1))
    end

    it "picks the oldest creation date when including descendants" do
      event1 = create(:event, created_at: Time.new(2025, 1, 1))
      _event2 = create(:event, created_at: Time.new(2024, 1, 1), parent: event1)

      instance = described_class.new(event1, include_descendants: true)

      expect(instance.start_date).to eq(Date.new(2024, 1, 1))
    end

    it "falls back to the current date" do
      freeze_time do
        travel_to(Time.new(2025, 1, 1))

        group = create(:event_group)

        instance = described_class.new(group)

        expect(instance.start_date).to eq(Date.new(2025, 1, 1))
      end
    end
  end

  describe "#end_date" do
    it "parses the param value if one is provided" do
      event = create(:event)
      instance = described_class.new(event, end_date_param: "2025-01-01")

      expect(instance.end_date).to eq(Date.new(2025, 1, 1))
    end

    it "falls back to the current date" do
      freeze_time do
        travel_to(Time.new(2025, 1, 1))
        event = create(:event)
        instance = described_class.new(event)

        expect(instance.start_date).to eq(Date.new(2025, 1, 1))
      end
    end
  end

  describe "#transactions_by_category" do
    it "returns a hash of transactions grouped by category with unknowns last" do
      event = create(:event)

      rent = create(:canonical_transaction, category_slug: "rent")
      create(:canonical_event_mapping, event:, canonical_transaction: rent)

      unknown = create(:canonical_transaction)
      create(:canonical_event_mapping, event:, canonical_transaction: unknown)

      instance = described_class.new(event, start_date_param: "1970-01-01")
      result = instance.transactions_by_category

      expect(result).to be_a(Hash)
      expect(result.keys).to eq([rent.category, nil])
      expect(result[rent.category]).to eq([rent])
      expect(result[nil]).to eq([unknown])
    end

    it "takes into account all transactions within a group" do
      group = create(:event_group)

      event1 = create(:event)
      group.memberships.create!(event: event1)
      event1_rent = create(:canonical_transaction, category_slug: "rent")
      create(:canonical_event_mapping, event: event1, canonical_transaction: event1_rent)

      event2 = create(:event)
      group.memberships.create!(event: event2)
      event2_unknown = create(:canonical_transaction)
      create(:canonical_event_mapping, event: event2, canonical_transaction: event2_unknown)

      instance = described_class.new(group, start_date_param: "1970-01-01")
      result = instance.transactions_by_category

      expect(result).to be_a(Hash)
      expect(result.keys).to eq([event1_rent.category, nil])
      expect(result[event1_rent.category]).to eq([event1_rent])
      expect(result[nil]).to eq([event2_unknown])
    end

    it "includes transactions from descendants when configured" do
      event1 = create(:event)
      event1_rent = create(:canonical_transaction, category_slug: "rent")
      create(:canonical_event_mapping, event: event1, canonical_transaction: event1_rent)

      event2 = create(:event, parent: event1)
      event2_unknown = create(:canonical_transaction)
      create(:canonical_event_mapping, event: event2, canonical_transaction: event2_unknown)

      instance = described_class.new(event1, start_date_param: "1970-01-01", include_descendants: true)
      result = instance.transactions_by_category

      expect(result).to be_a(Hash)
      expect(result.keys).to eq([event1_rent.category, nil])
      expect(result[event1_rent.category]).to eq([event1_rent])
      expect(result[nil]).to eq([event2_unknown])
    end

    it "honors the start date and end date" do
      event = create(:event, created_at: Time.new(2024, 1, 1))

      transactions = 1.upto(3).map do |day|
        canonical_transaction = create(
          :canonical_transaction,
          category_slug: "rent",
          date: Date.new(2025, 1, day)
        )
        create( :canonical_event_mapping, event:, canonical_transaction: )

        canonical_transaction
      end

      rent = TransactionCategory.find_by!(slug: "rent")

      result_with_start = described_class.new(event, start_date_param: "2025-01-02").transactions_by_category
      expect(result_with_start.keys).to eq([rent])
      expect(result_with_start[rent]).to contain_exactly(transactions[1], transactions[2])

      result_with_end = described_class.new(event, end_date_param: "2025-01-02").transactions_by_category
      expect(result_with_end.keys).to eq([rent])
      expect(result_with_end[rent]).to contain_exactly(transactions[0], transactions[1])
    end
  end

  describe "#category_totals, #net_asset_change, #total_revenue, #total_expense" do
    specify "repayments lower expenses instead of counting as revenue" do
      event = create(:event)

      [[100_00, "donations"], [-40_00, "repayment"], [-10_00, "rent"], [40_00, "repayment"]].each do |amount_cents, category_slug|
        transaction = create(:canonical_transaction, amount_cents:, category_slug:)
        create(:canonical_event_mapping, event:, canonical_transaction: transaction)
      end

      instance = described_class.new(event, start_date_param: "1970-01-01")

      expect(instance.total_revenue).to eq(100_00)
      expect(instance.total_expense).to eq(-10_00)
      expect(instance.net_asset_change).to eq(90_00)
      expect(instance.category_totals["repayment"]).to eq(0)
    end

    specify "single event" do
      event = create(:event)

      2.times do
        rent = create(:canonical_transaction, category_slug: "rent", amount_cents: 12_34)
        create(:canonical_event_mapping, event:, canonical_transaction: rent)
      end

      2.times do
        unknown = create(:canonical_transaction, amount_cents: -56_78)
        create(:canonical_event_mapping, event:, canonical_transaction: unknown)
      end

      instance = described_class.new(event, start_date_param: "1970-01-01")

      category_totals = instance.category_totals
      expect(category_totals).to be_a(Hash)
      expect(category_totals.keys).to eq(["rent", nil])
      expect(category_totals["rent"]).to eq(24_68)
      expect(category_totals[nil]).to eq(-113_56)

      expect(instance.net_asset_change).to eq(-88_88)
      expect(instance.total_revenue).to eq(24_68)
      expect(instance.total_expense).to eq(-113_56)
    end

    specify "group" do
      group = create(:event_group)
      event1, event2 = create_list(:event, 2)

      [event1, event2].each do |event|
        group.memberships.create!(event: event)

        rent = create(:canonical_transaction, category_slug: "rent", amount_cents: 12_34)
        create(:canonical_event_mapping, event:, canonical_transaction: rent)

        unknown = create(:canonical_transaction, amount_cents: -56_78)
        create(:canonical_event_mapping, event:, canonical_transaction: unknown)
      end

      instance = described_class.new(group, start_date_param: "1970-01-01")

      category_totals = instance.category_totals
      expect(category_totals).to be_a(Hash)
      expect(category_totals.keys).to eq(["rent", nil])
      expect(category_totals["rent"]).to eq(24_68)
      expect(category_totals[nil]).to eq(-113_56)

      expect(instance.net_asset_change).to eq(-88_88)
      expect(instance.total_revenue).to eq(24_68)
      expect(instance.total_expense).to eq(-113_56)
    end

    specify "with descendants" do
      event1, event2 = create_list(:event, 2)
      event2.update!(parent: event1)

      [event1, event2].each do |event|
        rent = create(:canonical_transaction, category_slug: "rent", amount_cents: 12_34)
        create(:canonical_event_mapping, event:, canonical_transaction: rent)

        unknown = create(:canonical_transaction, amount_cents: -56_78)
        create(:canonical_event_mapping, event:, canonical_transaction: unknown)
      end

      instance = described_class.new(event1, start_date_param: "1970-01-01", include_descendants: true)

      category_totals = instance.category_totals
      expect(category_totals).to be_a(Hash)
      expect(category_totals.keys).to eq(["rent", nil])
      expect(category_totals["rent"]).to eq(24_68)
      expect(category_totals[nil]).to eq(-113_56)

      expect(instance.net_asset_change).to eq(-88_88)
      expect(instance.total_revenue).to eq(24_68)
      expect(instance.total_expense).to eq(-113_56)
    end
  end

  describe "internal transfer splitting" do
    def create_disbursement_transaction(disbursement:, event:, hcb_code:, amount_cents:, category_slug: "internal-transfer")
      ct = create(:canonical_transaction, amount_cents:, category_slug:)
      create(:canonical_event_mapping, event:, canonical_transaction: ct)
      # Must set hcb_code after all after_create_commit callbacks have completed,
      # since write_hcb_code overwrites it based on the transaction source.
      CanonicalTransaction.where(id: ct.id).update_all(hcb_code:)
      ct.reload
    end

    it "classifies a disbursement as inter-org when only one side is in the statement" do
      event_a = create(:event)
      event_b = create(:event)
      disbursement = create(:disbursement, source_event: event_a, event: event_b)

      outgoing = create_disbursement_transaction(
        disbursement:, event: event_a,
        hcb_code: disbursement.outgoing_hcb_code, amount_cents: -10_00
      )

      instance = described_class.new(event_a, start_date_param: "1970-01-01")
      result = instance.transactions_by_category

      inter_org = described_class::INTER_ORG_TRANSFER
      expect(result.keys).to include(inter_org)
      expect(result[inter_org]).to eq([outgoing])
      expect(instance.category_totals["inter-organization-transfer"]).to eq(-10_00)
    end

    it "classifies both sides as intra-org when both events are in the statement" do
      group = create(:event_group)
      event_a = create(:event)
      event_b = create(:event)
      group.memberships.create!(event: event_a)
      group.memberships.create!(event: event_b)

      disbursement = create(:disbursement, source_event: event_a, event: event_b)

      outgoing = create_disbursement_transaction(
        disbursement:, event: event_a,
        hcb_code: disbursement.outgoing_hcb_code, amount_cents: -10_00
      )
      incoming = create_disbursement_transaction(
        disbursement:, event: event_b,
        hcb_code: disbursement.incoming_hcb_code, amount_cents: 10_00
      )

      instance = described_class.new(group, start_date_param: "1970-01-01")
      result = instance.transactions_by_category

      intra_org = described_class::INTRA_ORG_TRANSFER
      expect(result.keys).to include(intra_org)
      expect(result[intra_org]).to contain_exactly(outgoing, incoming)
      expect(instance.category_totals["intra-organization-transfer"]).to eq(0)
    end

    it "classifies as intra-org for parent/child with include_descendants" do
      event_a = create(:event)
      event_b = create(:event, parent: event_a)

      disbursement = create(:disbursement, source_event: event_a, event: event_b)

      outgoing = create_disbursement_transaction(
        disbursement:, event: event_a,
        hcb_code: disbursement.outgoing_hcb_code, amount_cents: -5_00
      )
      incoming = create_disbursement_transaction(
        disbursement:, event: event_b,
        hcb_code: disbursement.incoming_hcb_code, amount_cents: 5_00
      )

      instance = described_class.new(event_a, start_date_param: "1970-01-01", include_descendants: true)
      result = instance.transactions_by_category

      intra_org = described_class::INTRA_ORG_TRANSFER
      expect(result.keys).to include(intra_org)
      expect(result[intra_org]).to contain_exactly(outgoing, incoming)
      expect(instance.category_totals["intra-organization-transfer"]).to eq(0)
    end

    it "leaves intra-org transfers out of revenue and expense for a group, but keeps inter-org ones" do
      # #15898: the summary sentence would otherwise count money moved inside the group as both raised and spent.
      group = create(:event_group)
      event_a, event_b, outside = create_list(:event, 3)
      group.memberships.create!(event: event_a)
      group.memberships.create!(event: event_b)

      donation = create(:canonical_transaction, amount_cents: 1_000_00)
      create(:canonical_event_mapping, event: event_a, canonical_transaction: donation)

      internal = create(:disbursement, source_event: event_a, event: event_b)
      create_disbursement_transaction(disbursement: internal, event: event_a, hcb_code: internal.outgoing_hcb_code, amount_cents: -100_00)
      create_disbursement_transaction(disbursement: internal, event: event_b, hcb_code: internal.incoming_hcb_code, amount_cents: 100_00)

      external = create(:disbursement, source_event: event_b, event: outside)
      create_disbursement_transaction(disbursement: external, event: event_b, hcb_code: external.outgoing_hcb_code, amount_cents: -30_00)

      # #15898 only drops intra-org transfers, so money coming in from outside the group is still revenue.
      incoming = create(:disbursement, source_event: outside, event: event_a)
      create_disbursement_transaction(disbursement: incoming, event: event_a, hcb_code: incoming.incoming_hcb_code, amount_cents: 50_00)

      instance = described_class.new(group, start_date_param: "1970-01-01")

      expect(instance.total_revenue).to eq(1_050_00)
      expect(instance.total_expense).to eq(-30_00)
      expect(instance.net_asset_change).to eq(1_020_00)
    end

    it "leaves intra-org transfers out of revenue and expense for parent/child with include_descendants" do
      # #15898: same as the group case, for an organization's statement that includes its sub-organizations (e.g. /hq).
      parent = create(:event)
      child = create(:event, parent:)

      donation = create(:canonical_transaction, amount_cents: 1_000_00)
      create(:canonical_event_mapping, event: parent, canonical_transaction: donation)

      disbursement = create(:disbursement, source_event: parent, event: child)
      create_disbursement_transaction(disbursement:, event: parent, hcb_code: disbursement.outgoing_hcb_code, amount_cents: -100_00)
      create_disbursement_transaction(disbursement:, event: child, hcb_code: disbursement.incoming_hcb_code, amount_cents: 100_00)

      instance = described_class.new(parent, start_date_param: "1970-01-01", include_descendants: true)

      expect(instance.total_revenue).to eq(1_000_00)
      expect(instance.total_expense).to eq(0)
    end

    it "still counts an intra-org transfer leg whose other leg falls outside the date range" do
      # #15898: dropping a lone leg would leave raised + spent no longer adding up to the net change.
      group = create(:event_group)
      event_a, event_b = create_list(:event, 2)
      group.memberships.create!(event: event_a)
      group.memberships.create!(event: event_b)

      disbursement = create(:disbursement, source_event: event_a, event: event_b)
      outgoing = create_disbursement_transaction(disbursement:, event: event_a, hcb_code: disbursement.outgoing_hcb_code, amount_cents: -100_00)
      incoming = create_disbursement_transaction(disbursement:, event: event_b, hcb_code: disbursement.incoming_hcb_code, amount_cents: 100_00)
      outgoing.update!(date: Date.new(2025, 12, 31))
      incoming.update!(date: Date.new(2026, 1, 1))

      instance = described_class.new(group, start_date_param: "2026-01-01", end_date_param: "2026-01-31")

      expect(instance.net_asset_change).to eq(100_00)
      expect(instance.total_revenue).to eq(100_00)
      expect(instance.total_expense).to eq(0)
    end

    describe "payments (#15894)" do
      let(:event_a) { create(:event) }
      let(:supplies) { TransactionCategory.find_or_create_by!(slug: "project-supplies") }

      def create_payment(destination)
        disbursement = create(:disbursement, source_event: event_a, event: destination, transfer_type: "payment", source_transaction_category: supplies, destination_transaction_category: supplies)
        outgoing = create_disbursement_transaction(disbursement:, event: event_a, hcb_code: disbursement.outgoing_hcb_code, amount_cents: -10_00, category_slug: "project-supplies")
        incoming = create_disbursement_transaction(disbursement:, event: destination, hcb_code: disbursement.incoming_hcb_code, amount_cents: 10_00, category_slug: "project-supplies")
        [outgoing, incoming]
      end

      # #15894: paying an organization outside the statement is real spending.
      it "keeps a payment under its category when only one side is in the statement" do
        outgoing, _incoming = create_payment(create(:event))

        instance = described_class.new(event_a, start_date_param: "1970-01-01")

        expect(instance.transactions_by_category[supplies]).to eq([outgoing])
        expect(instance.category_totals).to eq("project-supplies" => -10_00)
      end

      # #15894: a payment between two organizations in the statement is neither's revenue or expense.
      it "moves both sides of a payment within the statement to intra-org transfers" do
        group = create(:event_group)
        event_b = create(:event)
        group.memberships.create!(event: event_a)
        group.memberships.create!(event: event_b)
        outgoing, incoming = create_payment(event_b)
        rent = create(:canonical_transaction, amount_cents: -3_00, category_slug: "rent")
        create(:canonical_event_mapping, event: event_a, canonical_transaction: rent)

        instance = described_class.new(group, start_date_param: "1970-01-01")
        result = instance.transactions_by_category

        expect(result[described_class::INTRA_ORG_TRANSFER]).to contain_exactly(outgoing, incoming)
        expect(result).not_to have_key(supplies)
        expect(instance.category_totals).to include("intra-organization-transfer" => 0, "rent" => -3_00)
        expect(instance.category_totals["project-supplies"].to_i).to eq(0)
      end

      # #15894: a sub-organization's payment from its parent nets out in the parent's combined statement.
      it "moves a payment between parent and child to intra-org transfers with include_descendants" do
        outgoing, incoming = create_payment(create(:event, parent: event_a))

        instance = described_class.new(event_a, start_date_param: "1970-01-01", include_descendants: true)

        expect(instance.transactions_by_category[described_class::INTRA_ORG_TRANSFER]).to contain_exactly(outgoing, incoming)
        expect(instance.category_totals["intra-organization-transfer"]).to eq(0)
      end

      # #15894: a payment marked as repaying an expense moves that expense onto the sender, so it must stay
      # under the expense's category, even when that's the payment's own category.
      it "keeps a payment that was marked as a repayment under the repaid expense's category" do
        group = create(:event_group)
        event_b = create(:event)
        group.memberships.create!(event: event_a)
        group.memberships.create!(event: event_b)
        expense = create(:canonical_transaction, amount_cents: -10_00, category_slug: "project-supplies")
        create(:canonical_event_mapping, event: event_b, canonical_transaction: expense)
        disbursement = create(:disbursement, :deposited, source_event: event_a, event: event_b, amount: 10_00, transfer_type: "payment", source_transaction_category: supplies, destination_transaction_category: supplies)
        outgoing = create_disbursement_transaction(disbursement:, event: event_a, hcb_code: disbursement.outgoing_hcb_code, amount_cents: -10_00, category_slug: "project-supplies")
        incoming = create_disbursement_transaction(disbursement:, event: event_b, hcb_code: disbursement.incoming_hcb_code, amount_cents: 10_00, category_slug: "project-supplies")
        [[outgoing, disbursement.outgoing_disbursement], [incoming, disbursement.incoming_disbursement]].each do |transaction, side|
          transaction.ledger_item.update_columns(linked_object_type: side.class.polymorphic_name, linked_object_id: side.id)
        end
        user = create(:user)
        create(:organizer_position, user:, event: event_a, role: :manager)
        create(:organizer_position, user:, event: event_b, role: :member)
        # The sender's side takes the expense's category, the recipient's becomes a repayment.
        RepaymentService::Mark.new(ledger_item: incoming.ledger_item.reload, other_ledger_item_hashid: expense.ledger_item.reload.hashid, created_by: user).run

        result = described_class.new(group, start_date_param: "1970-01-01").transactions_by_category

        expect(result[supplies]).to eq([outgoing])
        expect(result).not_to have_key(described_class::INTRA_ORG_TRANSFER)
      end

      # #15894: repayments_received already takes a repayment leg out of revenue, so moving it to intra-org would count it twice.
      it "keeps a payment leg an admin set to repayment under repayment" do
        group = create(:event_group)
        event_b = create(:event)
        group.memberships.create!(event: event_a)
        group.memberships.create!(event: event_b)
        outgoing, incoming = create_payment(event_b)
        incoming.category_mapping.update!(category: TransactionCategory.find_or_create_by!(slug: Repayment::CATEGORY_SLUG))

        result = described_class.new(group, start_date_param: "1970-01-01").transactions_by_category

        expect(result[described_class::INTRA_ORG_TRANSFER]).to eq([outgoing])
        expect(result[TransactionCategory.find_by!(slug: Repayment::CATEGORY_SLUG)]).to eq([incoming.reload])
      end
    end
  end
end
