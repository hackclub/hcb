# frozen_string_literal: true

require "rails_helper"

RSpec.describe Disbursement, type: :model do
  def add_balance_to_event(event)
    ct = create(:canonical_transaction, amount_cents: 100_000, memo: "Test balance")
    create(:canonical_event_mapping, canonical_transaction: ct, event: event)
  end

  # Captures application SQL (ignoring schema + transaction-control statements) run
  # inside the block, so a code path can be asserted to issue no queries.
  def application_sql_in
    statements = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      payload = ActiveSupport::Notifications::Event.new(*args).payload
      next if payload[:name] == "SCHEMA"
      next if payload[:sql] =~ /\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i

      statements << payload[:sql]
    end
    yield
    statements
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  # The :with_raw_pending_transactions trait creates RAW pending transactions, which
  # only become canonical pending transactions once the import engine runs. Transition
  # side-effects (fronting / declining) operate on the canonical pending transactions,
  # so create both legs directly to actually exercise them.
  def create_canonical_pending_transactions(disbursement)
    outgoing = create(:canonical_pending_transaction, amount_cents: -disbursement.amount)
    outgoing.update_column(:hcb_code, disbursement.outgoing_hcb_code)
    incoming = create(:canonical_pending_transaction, amount_cents: disbursement.amount)
    incoming.update_column(:hcb_code, disbursement.incoming_hcb_code)
    [outgoing, incoming]
  end

  let(:disbursement) { create(:disbursement) }

  it "is valid" do
    expect(disbursement).to be_valid
  end

  describe "state machine" do
    describe "initial state" do
      it "starts in reviewing state" do
        expect(disbursement).to be_reviewing
      end
    end

    describe "#mark_approved" do
      context "from reviewing state" do
        let(:user) { create(:user) }
        let(:disbursement) { create(:disbursement, :with_raw_pending_transactions) }

        it "transitions to pending" do
          disbursement.mark_approved!(user)
          expect(disbursement).to be_pending
        end

        it "sets fulfilled_by" do
          disbursement.mark_approved!(user)
          expect(disbursement.fulfilled_by).to eq(user)
        end

        it "fronts both legs' canonical pending transactions" do
          cpts = create_canonical_pending_transactions(disbursement)

          disbursement.mark_approved!(user)

          expect(cpts.map { |cpt| cpt.reload.fronted }).to eq([true, true])
        end
      end

      context "from scheduled state" do
        let(:user) { create(:user) }
        let(:disbursement) { create(:disbursement, :scheduled, :with_raw_pending_transactions) }

        it "transitions to pending" do
          disbursement.mark_approved!(user)
          expect(disbursement).to be_pending
        end

        it "sets fulfilled_by" do
          new_user = create(:user)
          disbursement.mark_approved!(new_user)
          expect(disbursement.fulfilled_by).to eq(new_user)
        end
      end
    end

    describe "#mark_scheduled" do
      let(:user) { create(:user) }

      context "from reviewing state" do
        it "transitions to scheduled" do
          disbursement.mark_scheduled!(user)
          expect(disbursement).to be_scheduled
        end

        it "sets fulfilled_by" do
          disbursement.mark_scheduled!(user)
          expect(disbursement.fulfilled_by).to eq(user)
        end
      end

      context "from pending state" do
        let(:disbursement) { create(:disbursement, :pending) }

        it "transitions to scheduled" do
          disbursement.mark_scheduled!(user)
          expect(disbursement).to be_scheduled
        end
      end
    end

    describe "#mark_in_transit" do
      context "from pending state" do
        let(:disbursement) { create(:disbursement, :pending) }

        it "transitions to in_transit" do
          disbursement.mark_in_transit!
          expect(disbursement).to be_in_transit
        end
      end

      context "from scheduled state" do
        let(:disbursement) { create(:disbursement, :scheduled) }

        it "transitions to in_transit" do
          disbursement.mark_in_transit!
          expect(disbursement).to be_in_transit
        end
      end
    end

    describe "#mark_deposited" do
      context "from in_transit state" do
        let(:disbursement) { create(:disbursement, :in_transit) }

        it "transitions to deposited" do
          disbursement.mark_deposited!
          expect(disbursement).to be_deposited
        end
      end
    end

    describe "#mark_rejected" do
      let(:user) { create(:user) }

      context "from reviewing state" do
        let(:disbursement) { create(:disbursement, :with_raw_pending_transactions) }

        it "transitions to rejected" do
          disbursement.mark_rejected!(user)
          expect(disbursement).to be_rejected
        end

        it "sets fulfilled_by" do
          disbursement.mark_rejected!(user)
          expect(disbursement.fulfilled_by).to eq(user)
        end

        it "declines both legs' canonical pending transactions" do
          cpts = create_canonical_pending_transactions(disbursement)

          disbursement.mark_rejected!(user)

          expect(cpts.map { |cpt| cpt.reload.declined? }).to eq([true, true])
        end

        it "creates rejection activity" do
          PublicActivity.with_tracking do
            expect {
              disbursement.mark_rejected!(user)
            }.to change { PublicActivity::Activity.where(trackable: disbursement, key: "disbursement.rejected").count }.by(1)
          end
        end
      end

      context "from pending state" do
        let(:disbursement) { create(:disbursement, :pending, :with_raw_pending_transactions) }

        it "transitions to rejected" do
          disbursement.mark_rejected!(user)
          expect(disbursement).to be_rejected
        end
      end

      context "from scheduled state" do
        let(:disbursement) { create(:disbursement, :scheduled, :with_raw_pending_transactions) }

        it "transitions to rejected" do
          disbursement.mark_rejected!(user)
          expect(disbursement).to be_rejected
        end
      end
    end

    describe "#mark_errored" do
      context "from pending state" do
        let(:disbursement) { create(:disbursement, :pending, :with_raw_pending_transactions) }

        it "transitions to errored" do
          disbursement.mark_errored!
          expect(disbursement).to be_errored
        end

        it "declines both legs' canonical pending transactions" do
          cpts = create_canonical_pending_transactions(disbursement)

          disbursement.mark_errored!

          expect(cpts.map { |cpt| cpt.reload.declined? }).to eq([true, true])
        end
      end

      context "from in_transit state" do
        let(:disbursement) { create(:disbursement, :in_transit, :with_raw_pending_transactions) }

        it "transitions to errored" do
          disbursement.mark_errored!
          expect(disbursement).to be_errored
        end
      end
    end
  end

  describe "validations" do
    # Note: source_event_id and event_id presence validations can't be easily tested
    # because the frozen check callback runs first and raises NoMethodError on nil

    it "requires amount" do
      disbursement = build(:disbursement, amount: nil)
      expect(disbursement).not_to be_valid
      expect(disbursement.errors[:amount]).to include("can't be blank")
    end

    it "requires name" do
      disbursement = build(:disbursement, name: nil)
      expect(disbursement).not_to be_valid
      expect(disbursement.errors[:name]).to include("can't be blank")
    end

    it "requires amount to be greater than 0" do
      disbursement = build(:disbursement, amount: 0)
      expect(disbursement).not_to be_valid
      expect(disbursement.errors[:amount]).to include("must be greater than 0")
    end

    it "does not allow negative amounts" do
      disbursement = build(:disbursement, amount: -100)
      expect(disbursement).not_to be_valid
      expect(disbursement.errors[:amount]).to include("must be greater than 0")
    end

    describe "events_are_different" do
      it "does not allow same source and destination event" do
        event = create(:event)
        disbursement = build(:disbursement, event: event, source_event: event)
        expect(disbursement).not_to be_valid
        expect(disbursement.errors[:event]).to include("must be different than source event")
      end

      it "allows same event with different subledgers" do
        event = create(:event)
        source_subledger = create(:subledger, event: event)
        destination_subledger = create(:subledger, event: event)
        disbursement = build(:disbursement, event: event, source_event: event,
                                            source_subledger: source_subledger,
                                            destination_subledger: destination_subledger)
        expect(disbursement.errors[:event]).to be_empty
      end
    end

    describe "events_are_not_demos" do
      it "does not allow demo destination event on create" do
        demo_event = create(:event, :demo_mode)
        disbursement = build(:disbursement, event: demo_event)
        expect(disbursement).not_to be_valid
        expect(disbursement.errors[:event]).to include("cannot be a demo event")
      end

      it "does not allow demo source event on create" do
        demo_event = create(:event, :demo_mode)
        disbursement = build(:disbursement, source_event: demo_event)
        expect(disbursement).not_to be_valid
        expect(disbursement.errors[:source_event]).to include("cannot be a demo event")
      end
    end

    describe "scheduled_on_must_be_in_the_future" do
      it "does not allow scheduled_on in the past" do
        disbursement = build(:disbursement, scheduled_on: 1.day.ago)
        expect(disbursement).not_to be_valid
        expect(disbursement.errors[:scheduled_on]).to include("must be in the future")
      end

      it "does not allow scheduled_on today" do
        disbursement = build(:disbursement, scheduled_on: Date.today)
        expect(disbursement).not_to be_valid
        expect(disbursement.errors[:scheduled_on]).to include("must be in the future")
      end

      it "allows scheduled_on in the future" do
        disbursement = build(:disbursement, scheduled_on: 1.week.from_now.to_date)
        disbursement.valid?
        expect(disbursement.errors[:scheduled_on]).to be_empty
      end

      it "allows nil scheduled_on" do
        disbursement = build(:disbursement, scheduled_on: nil)
        disbursement.valid?
        expect(disbursement.errors[:scheduled_on]).to be_empty
      end
    end

    describe "frozen source event" do
      it "blocks creation when source event is frozen" do
        frozen_event = create(:event)
        frozen_event.update!(financially_frozen: true)
        disbursement = build(:disbursement, source_event: frozen_event)
        expect(disbursement).not_to be_valid
        expect(disbursement.errors[:base].first).to include("is currently frozen")
      end
    end
  end

  describe "Disbursement::Incoming" do
    let(:incoming) { disbursement.incoming_disbursement }

    describe "#counterparty_label" do
      it "returns the source event name" do
        expect(incoming.counterparty_label).to eq(disbursement.source_event.name)
      end

      context "with a card grant subledger" do
        let(:card_grant) do
          add_balance_to_event(disbursement.source_event)
          create(:card_grant, event: disbursement.source_event)
        end

        before do
          disbursement.update!(source_subledger: card_grant.subledger)
        end

        it "returns the grant recipient name" do
          expect(incoming.counterparty_label).to eq("Grant recipient #{card_grant.user.name}")
        end
      end
    end

    describe "#self_label" do
      it "returns the destination event name" do
        expect(incoming.self_label).to eq(disbursement.destination_event.name)
      end

      context "with a card grant subledger" do
        let(:card_grant) do
          add_balance_to_event(disbursement.destination_event)
          create(:card_grant, event: disbursement.destination_event)
        end

        before do
          disbursement.update!(destination_subledger: card_grant.subledger)
        end

        it "returns the grant recipient name" do
          expect(incoming.self_label).to eq("Grant recipient #{card_grant.user.name}")
        end
      end
    end

    describe "may_mark_* delegation" do
      %i[may_mark_approved? may_mark_in_transit? may_mark_deposited? may_mark_errored? may_mark_rejected? may_mark_scheduled?].each do |method|
        it "delegates #{method} to disbursement" do
          expect(incoming.disbursement).to receive(method)
          incoming.public_send(method)
        end
      end
    end
  end

  describe "Disbursement::Outgoing" do
    let(:outgoing) { disbursement.outgoing_disbursement }

    describe "#counterparty_label" do
      it "returns the destination event name" do
        expect(outgoing.counterparty_label).to eq(disbursement.destination_event.name)
      end

      context "with a card grant subledger" do
        let(:card_grant) do
          add_balance_to_event(disbursement.destination_event)
          create(:card_grant, event: disbursement.destination_event)
        end

        before do
          disbursement.update!(destination_subledger: card_grant.subledger)
        end

        it "returns the grant recipient name" do
          expect(outgoing.counterparty_label).to eq("Grant recipient #{card_grant.user.name}")
        end
      end
    end

    describe "#self_label" do
      it "returns the source event name" do
        expect(outgoing.self_label).to eq(disbursement.source_event.name)
      end

      context "with a card grant subledger" do
        let(:card_grant) do
          add_balance_to_event(disbursement.source_event)
          create(:card_grant, event: disbursement.source_event)
        end

        before do
          disbursement.update!(source_subledger: card_grant.subledger)
        end

        it "returns the grant recipient name" do
          expect(outgoing.self_label).to eq("Grant recipient #{card_grant.user.name}")
        end
      end
    end

    describe "may_mark_* delegation" do
      %i[may_mark_approved? may_mark_in_transit? may_mark_deposited? may_mark_errored? may_mark_rejected? may_mark_scheduled?].each do |method|
        it "delegates #{method} to disbursement" do
          expect(outgoing.disbursement).to receive(method)
          outgoing.public_send(method)
        end
      end
    end
  end

  describe "helper methods" do

    describe "#outgoing_hcb_code" do
      it "returns the correct HCB code format" do
        expect(disbursement.outgoing_hcb_code).to eq("HCB-500-#{disbursement.id}")
      end
    end

    describe "#incoming_hcb_code" do
      it "returns the correct HCB code format" do
        expect(disbursement.incoming_hcb_code).to eq("HCB-550-#{disbursement.id}")
      end
    end

    describe "#all_comments" do
      let(:user) { create(:user) }

      it "includes comments from the disbursement and both sides" do
        outgoing_hcb_code = disbursement.outgoing_disbursement.local_hcb_code
        incoming_hcb_code = disbursement.incoming_disbursement.local_hcb_code

        disbursement_comment = create(:comment, commentable: disbursement, user:)
        outgoing_comment = create(:comment, commentable: outgoing_hcb_code, user:)
        incoming_comment = create(:comment, commentable: incoming_hcb_code, user:)

        expect(disbursement.all_comments).to contain_exactly(disbursement_comment, outgoing_comment, incoming_comment)
      end
    end

    describe "#canonical_transactions" do
      it "returns CTs with matching hcb_code" do
        ct1 = create(:canonical_transaction)
        ct1.update_column(:hcb_code, disbursement.outgoing_hcb_code)
        ct2 = create(:canonical_transaction)
        ct2.update_column(:hcb_code, disbursement.outgoing_hcb_code)
        create(:canonical_transaction) # unrelated CT

        # Clear memoization
        disbursement.instance_variable_set(:@canonical_transactions, nil)
        expect(disbursement.canonical_transactions).to contain_exactly(ct1, ct2)
      end

      it "returns empty when no matching CTs" do
        expect(disbursement.canonical_transactions).to be_empty
      end
    end

    describe "#canonical_pending_transactions" do
      it "returns CPTs with matching hcb_code" do
        # Create CPTs manually and set their hcb_code after creation
        cpt1 = create(:canonical_pending_transaction, amount_cents: -disbursement.amount)
        cpt1.update_column(:hcb_code, disbursement.outgoing_hcb_code)
        cpt2 = create(:canonical_pending_transaction, amount_cents: disbursement.amount)
        cpt2.update_column(:hcb_code, disbursement.outgoing_hcb_code)

        # Clear memoization
        disbursement.instance_variable_set(:@canonical_pending_transactions, nil)
        cpts = disbursement.canonical_pending_transactions
        expect(cpts.count).to eq(2)
        cpts.each do |cpt|
          expect(cpt.hcb_code).to eq(disbursement.outgoing_hcb_code)
        end
      end
    end

    describe "#processed?" do
      it "returns true when in_transit" do
        disbursement = create(:disbursement, :in_transit)
        expect(disbursement.processed?).to be true
      end

      it "returns true when deposited" do
        disbursement = create(:disbursement, :deposited)
        expect(disbursement.processed?).to be true
      end

      it "returns false when reviewing" do
        expect(disbursement.processed?).to be false
      end

      it "returns false when pending" do
        disbursement = create(:disbursement, :pending)
        expect(disbursement.processed?).to be false
      end
    end

    describe "#fulfilled?" do
      it "returns true when deposited" do
        disbursement = create(:disbursement, :deposited)
        expect(disbursement.fulfilled?).to be true
      end

      it "returns false when in_transit" do
        disbursement = create(:disbursement, :in_transit)
        expect(disbursement.fulfilled?).to be false
      end

      it "returns false when pending" do
        disbursement = create(:disbursement, :pending)
        expect(disbursement.fulfilled?).to be false
      end
    end

    describe "#state" do
      it "returns :success when fulfilled" do
        disbursement = create(:disbursement, :deposited)
        expect(disbursement.state).to eq(:success)
      end

      it "returns :error when rejected" do
        disbursement = create(:disbursement, :rejected)
        expect(disbursement.state).to eq(:error)
      end

      it "returns :error when errored" do
        disbursement = create(:disbursement, :errored)
        expect(disbursement.state).to eq(:error)
      end

      it "returns :info when scheduled" do
        disbursement = create(:disbursement, :scheduled)
        expect(disbursement.state).to eq(:info)
      end

      it "returns :muted when reviewing" do
        expect(disbursement.state).to eq(:muted)
      end
    end

    describe "#state_text" do
      it "returns 'fulfilled' when deposited" do
        disbursement = create(:disbursement, :deposited)
        expect(disbursement.state_text).to eq("fulfilled")
      end

      it "returns 'rejected' when rejected without prior approval" do
        disbursement = create(:disbursement, :rejected)
        expect(disbursement.state_text).to eq("rejected")
      end

      it "returns 'canceled' when rejected after approval" do
        disbursement = create(:disbursement, :rejected, pending_at: 1.day.ago)
        expect(disbursement.state_text).to eq("canceled")
      end

      it "returns 'scheduled' when scheduled" do
        disbursement = create(:disbursement, :scheduled)
        expect(disbursement.state_text).to eq("scheduled")
      end

      it "returns 'errored' when errored" do
        disbursement = create(:disbursement, :errored)
        expect(disbursement.state_text).to eq("errored")
      end

      it "returns 'pending' when reviewing" do
        expect(disbursement.state_text).to eq("pending")
      end
    end

    describe "#transferred_at" do
      it "returns approved_at when set" do
        freeze_time do
          disbursement = create(:disbursement, :pending)
          expect(disbursement.transferred_at).to eq(disbursement.approved_at)
        end
      end

      it "falls back to in_transit_at when approved_at is nil" do
        freeze_time do
          disbursement = create(:disbursement, :in_transit, pending_at: nil)
          expect(disbursement.transferred_at).to eq(disbursement.in_transit_at)
        end
      end
    end
  end

  describe "AASM events" do
    let(:incoming) { disbursement.incoming_disbursement }
    let(:outgoing) { disbursement.outgoing_disbursement }

    it "Disbursement responds to all aasm event methods" do
      %i[mark_approved! mark_in_transit! mark_deposited! mark_errored! mark_rejected! mark_scheduled!].each do |method|
        expect(disbursement).to respond_to(method)
      end
    end

    it "Disbursement has all aasm events defined on the class" do
      expect(Disbursement.aasm.events.map(&:name)).to match_array(
        %i[mark_approved mark_in_transit mark_deposited mark_errored mark_rejected mark_scheduled]
      )
    end

    it "Disbursement::Incoming does not respond to any aasm event methods" do
      %i[mark_approved! mark_in_transit! mark_deposited! mark_errored! mark_rejected! mark_scheduled!].each do |method|
        expect(incoming).not_to respond_to(method)
      end
    end

    it "Disbursement::Incoming has no aasm events defined" do
      expect(Disbursement::Incoming.aasm.events).to be_empty
    end

    it "Disbursement::Outgoing does not respond to any aasm event methods" do
      %i[mark_approved! mark_in_transit! mark_deposited! mark_errored! mark_rejected! mark_scheduled!].each do |method|
        expect(outgoing).not_to respond_to(method)
      end
    end

    it "Disbursement::Outgoing has no aasm events defined" do
      expect(Disbursement::Outgoing.aasm.events).to be_empty
    end
  end

  describe "AASM state definitions from Shared" do
    it "states are defined identically on Disbursement, Disbursement::Incoming, and Disbursement::Outgoing" do
      shared_states = %i[reviewing pending scheduled in_transit deposited rejected errored]
      expect(Disbursement.aasm.states.map(&:name)).to match_array(shared_states)
      expect(Disbursement::Incoming.aasm.states.map(&:name)).to match_array(shared_states)
      expect(Disbursement::Outgoing.aasm.states.map(&:name)).to match_array(shared_states)
    end

    it "Disbursement does not redeclare states from Shared (no duplicate state entries)" do
      state_names = Disbursement.aasm.states.map(&:name)
      expect(state_names).to eq(state_names.uniq)
    end
  end

  describe "incoming/outgoing lenses (becomes)" do
    it "returns the matching subclass for each perspective" do
      expect(disbursement.incoming_disbursement).to be_a(Disbursement::Incoming)
      expect(disbursement.outgoing_disbursement).to be_a(Disbursement::Outgoing)
    end

    it "represents one row, so both lenses carry the disbursement's id" do
      expect(disbursement.incoming_disbursement.id).to eq(disbursement.id)
      expect(disbursement.outgoing_disbursement.id).to eq(disbursement.id)
    end

    describe "amount sign" do
      it "reads positive through the incoming lens and negative through the outgoing lens" do
        expect(disbursement.incoming_disbursement.amount).to eq(disbursement.amount)
        expect(disbursement.outgoing_disbursement.amount).to eq(-disbursement.amount)
      end

      it "leaves the underlying column positive" do
        expect(disbursement.amount).to be_positive
        expect(Disbursement.where(id: disbursement.id).sum(:amount)).to eq(disbursement.amount)
      end
    end

    it "treats the two legs as distinct records despite the shared id" do
      incoming = disbursement.incoming_disbursement
      outgoing = disbursement.outgoing_disbursement

      expect(incoming).not_to eq(outgoing)
      expect(incoming).not_to eq(disbursement)
      expect([incoming, outgoing, disbursement].uniq.size).to eq(3)
    end

    it "reflects live changes to the underlying disbursement through the lens" do
      outgoing = disbursement.outgoing_disbursement
      disbursement.amount += 100

      expect(outgoing.amount).to eq(-disbursement.amount)
    end

    describe "signed-leg transaction separation" do
      it "routes the positive leg to the incoming lens and the negative leg to the outgoing lens" do
        incoming_ct = create(:canonical_transaction, amount_cents: disbursement.amount)
        incoming_ct.update_column(:hcb_code, disbursement.incoming_hcb_code)
        outgoing_ct = create(:canonical_transaction, amount_cents: -disbursement.amount)
        outgoing_ct.update_column(:hcb_code, disbursement.outgoing_hcb_code)

        expect(disbursement.incoming_disbursement.canonical_transactions).to contain_exactly(incoming_ct)
        expect(disbursement.outgoing_disbursement.canonical_transactions).to contain_exactly(outgoing_ct)
      end

      it "scopes pending transactions to each leg's own hcb_code" do
        incoming_cpt = create(:canonical_pending_transaction, amount_cents: disbursement.amount)
        incoming_cpt.update_column(:hcb_code, disbursement.incoming_hcb_code)
        outgoing_cpt = create(:canonical_pending_transaction, amount_cents: -disbursement.amount)
        outgoing_cpt.update_column(:hcb_code, disbursement.outgoing_hcb_code)

        expect(disbursement.incoming_disbursement.canonical_pending_transactions).to contain_exactly(incoming_cpt)
        expect(disbursement.outgoing_disbursement.canonical_pending_transactions).to contain_exactly(outgoing_cpt)
      end
    end

    it "builds both lenses, the reverse, and the counterparty without extra SQL" do
      loaded = Disbursement.find(disbursement.id)

      statements = application_sql_in do
        outgoing = loaded.outgoing_disbursement
        incoming = loaded.incoming_disbursement
        outgoing.disbursement
        outgoing.counterparty
        incoming.amount
        outgoing.hcb_code
      end

      expect(statements).to be_empty, "expected no SQL, got:\n#{statements.join("\n")}"
    end
  end

  describe "Event#incoming_disbursements / #outgoing_disbursements" do
    let(:source_event) { disbursement.source_event }
    let(:destination_event) { disbursement.destination_event }

    it "surfaces the transfer as a Disbursement::Incoming on the destination event" do
      expect(destination_event.incoming_disbursements).to all(be_a(Disbursement::Incoming))
      expect(destination_event.incoming_disbursements.map(&:id)).to include(disbursement.id)
    end

    it "surfaces the transfer as a Disbursement::Outgoing on the source event" do
      expect(source_event.outgoing_disbursements).to all(be_a(Disbursement::Outgoing))
      expect(source_event.outgoing_disbursements.map(&:id)).to include(disbursement.id)
    end

    it "does not surface the transfer on the opposite sides" do
      expect(source_event.incoming_disbursements).to be_empty
      expect(destination_event.outgoing_disbursements).to be_empty
    end

    it "keeps the SQL sum positive even though the outgoing lens reads each amount negative" do
      expect(source_event.outgoing_disbursements.sum(:amount)).to eq(disbursement.amount)
      expect(source_event.outgoing_disbursements.first.amount).to eq(-disbursement.amount)
    end
  end

  describe "may_mark_* guard delegation" do
    # Each lens carries AASM states but no events (they were split onto Disbursement),
    # so every transition guard must be delegated. Derive the guard list from the
    # events themselves, so a newly added event can't silently lose its lens guard.
    guard_methods = Disbursement.aasm.events.map { |event| :"may_#{event.name}?" }

    it "derives one guard per Disbursement AASM event" do
      expect(guard_methods).not_to be_empty
      expect(guard_methods.size).to eq(Disbursement.aasm.events.size)
    end

    it "the lenses define no events of their own, so the guards can only be delegated" do
      expect(Disbursement::Incoming.aasm.events).to be_empty
      expect(Disbursement::Outgoing.aasm.events).to be_empty
    end

    %i[incoming_disbursement outgoing_disbursement].each do |lens_method|
      context "on ##{lens_method}" do
        guard_methods.each do |guard|
          it "delegates #{guard} to the underlying disbursement" do
            lens = disbursement.public_send(lens_method)
            expect(lens).to respond_to(guard)
            expect(lens.public_send(guard)).to eq(disbursement.public_send(guard))
          end
        end
      end
    end

    context "guard values track the underlying state" do
      # Pulled from the state machine so a newly added state is covered automatically.
      Disbursement.aasm.states.map(&:name).each do |state|
        it "match the disbursement when #{state}" do
          subject = create(:disbursement, aasm_state: state.to_s)

          guard_methods.each do |guard|
            expect(subject.incoming_disbursement.public_send(guard)).to eq(subject.public_send(guard))
            expect(subject.outgoing_disbursement.public_send(guard)).to eq(subject.public_send(guard))
          end
        end
      end
    end
  end

  describe "AASM transition guards" do
    it "permits mark_approved only from reviewing or scheduled" do
      expect(create(:disbursement).may_mark_approved?).to be(true) # reviewing
      expect(create(:disbursement, :scheduled).may_mark_approved?).to be(true)
      expect(create(:disbursement, :pending).may_mark_approved?).to be(false)
      expect(create(:disbursement, :in_transit).may_mark_approved?).to be(false)
      expect(create(:disbursement, :deposited).may_mark_approved?).to be(false)
    end

    it "raises on an illegal transition" do
      expect { create(:disbursement).mark_deposited! }.to raise_error(AASM::InvalidTransition)
    end
  end

  describe "AASM state-machine configuration" do
    # The config and the state-stamping callback are established by the FIRST aasm
    # block (Shared's); Disbursement's block only adds events. These guard against the
    # config silently drifting if the blocks are rearranged again.
    it "enables timestamps and whiny_persistence on Disbursement and both lenses" do
      [Disbursement, Disbursement::Incoming, Disbursement::Outgoing].each do |klass|
        config = klass.aasm.state_machine.config
        expect(config.timestamps).to be(true), "expected #{klass} to enable timestamps"
        expect(config.whiny_persistence).to be(true), "expected #{klass} to enable whiny_persistence"
      end
    end

    it "raises ActiveRecord::RecordInvalid when a transition cannot be saved (whiny_persistence)" do
      disbursement = create(:disbursement, :pending)
      disbursement.name = nil # break a validation so the transition's save fails

      expect { disbursement.mark_in_transit! }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "AASM timestamps on transition" do
    let(:user) { create(:user) }

    it "stamps pending_at / approved_at when approved" do
      disbursement = create(:disbursement, :with_raw_pending_transactions)
      freeze_time do
        disbursement.mark_approved!(user)
        expect(disbursement.pending_at).to eq(Time.current)
        expect(disbursement.approved_at).to eq(disbursement.pending_at)
      end
    end

    it "stamps in_transit_at when marked in transit" do
      disbursement = create(:disbursement, :pending)
      freeze_time do
        disbursement.mark_in_transit!
        expect(disbursement.in_transit_at).to eq(Time.current)
      end
    end

    it "stamps deposited_at when deposited" do
      disbursement = create(:disbursement, :in_transit)
      freeze_time do
        disbursement.mark_deposited!
        expect(disbursement.deposited_at).to eq(Time.current)
      end
    end

    it "stamps rejected_at when rejected" do
      disbursement = create(:disbursement)
      freeze_time do
        disbursement.mark_rejected!(user)
        expect(disbursement.rejected_at).to eq(Time.current)
      end
    end

    it "stamps errored_at when errored" do
      disbursement = create(:disbursement, :pending)
      freeze_time do
        disbursement.mark_errored!
        expect(disbursement.errored_at).to eq(Time.current)
      end
    end
  end

  describe "AASM state scopes (create_scopes)" do
    it "generates a scope per state that filters by aasm_state" do
      deposited = create(:disbursement, :deposited)

      expect(Disbursement.deposited).to include(deposited)
      expect(Disbursement.deposited).not_to include(disbursement) # reviewing
      expect(Disbursement.reviewing).to include(disbursement)
    end

    it "backs the app scopes built on AASM states" do
      deposited = create(:disbursement, :deposited)
      in_transit = create(:disbursement, :in_transit)

      expect(Disbursement.fulfilled).to include(deposited)        # fulfilled -> deposited
      expect(Disbursement.processing).to include(in_transit)      # processing -> in_transit
    end
  end

  describe "state display fronting branches" do
    # state / state_text / state_icon all branch on whether the destination event can
    # front the balance while the transfer is still processing.
    describe "#state_icon" do
      it "is a checkmark when fulfilled" do
        expect(create(:disbursement, :deposited).state_icon).to eq("checkmark")
      end

      it "is a checkmark when processed (in_transit)" do
        expect(create(:disbursement, :in_transit).state_icon).to eq("checkmark")
      end

      it "is nil when reviewing" do
        expect(disbursement.state_icon).to be_nil
      end

      it "is a checkmark when pending and the destination event can front the balance" do
        disbursement = create(:disbursement, :pending)
        allow(disbursement.destination_event).to receive(:can_front_balance?).and_return(true)
        expect(disbursement.state_icon).to eq("checkmark")
      end

      it "is nil when pending and the destination event cannot front the balance" do
        disbursement = create(:disbursement, :pending)
        allow(disbursement.destination_event).to receive(:can_front_balance?).and_return(false)
        expect(disbursement.state_icon).to be_nil
      end
    end

    context "while processing, when the destination event can front the balance" do
      it "reads as a fulfilled success" do
        disbursement = create(:disbursement, :in_transit)
        allow(disbursement.destination_event).to receive(:can_front_balance?).and_return(true)

        expect(disbursement.state).to eq(:success)
        expect(disbursement.state_text).to eq("fulfilled")
      end
    end

    context "while processing, when the destination event cannot front the balance" do
      it "reads as muted and still processing" do
        disbursement = create(:disbursement, :in_transit)
        allow(disbursement.destination_event).to receive(:can_front_balance?).and_return(false)

        expect(disbursement.state).to eq(:muted)
        expect(disbursement.state_text).to eq("processing")
      end
    end
  end
end
