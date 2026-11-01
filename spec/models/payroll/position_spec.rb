# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payroll::Position, type: :model do
  describe "#status" do
    {
      "under_review" => :onboarding,
      "onboarding"   => :onboarding,
      "onboarded"    => :active,
      "expired"      => :completed,
    }.each do |aasm_state, expected|
      it "maps #{aasm_state} to #{expected}" do
        position = described_class.new(aasm_state:)
        expect(position.status).to eq(expected)
      end
    end
  end

  describe "#period_label" do
    it "returns nil when there is no start date" do
      expect(described_class.new(start_date: nil).period_label).to be_nil
    end

    it "shows a single date when there is no end date" do
      position = described_class.new(start_date: Date.new(2026, 4, 1))
      expect(position.period_label).to eq("Apr 1, 2026")
    end

    it "collapses to a single month when start and end fall in the same month" do
      position = described_class.new(start_date: Date.new(2026, 4, 1), end_date: Date.new(2026, 4, 28))
      expect(position.period_label).to eq("Apr 1–28, 2026")
    end

    it "shows a range within the same year" do
      position = described_class.new(start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 6, 30))
      expect(position.period_label).to eq("Jan 1 – Jun 30, 2026")
    end

    it "spans years when start and end fall in different years" do
      position = described_class.new(start_date: Date.new(2025, 12, 1), end_date: Date.new(2026, 2, 28))
      expect(position.period_label).to eq("Dec 1, 2025 – Feb 28, 2026")
    end
  end

  describe "date validations" do
    let(:payee) { create(:payee) }

    def build_position(**attrs)
      build(:payroll_position, payee:, **attrs)
    end

    it "requires the end date to be after the start date" do
      position = build_position(start_date: Date.current, end_date: Date.current)
      expect(position).to be_invalid
      expect(position.errors[:end_date]).to include("must be after the start date")
    end

    it "rejects a start date more than the max lead time in the future" do
      position = build_position(
        start_date: (Payroll::Position::MAX_START_LEAD_TIME.from_now + 1.day).to_date,
        end_date: (Payroll::Position::MAX_START_LEAD_TIME.from_now + 2.days).to_date
      )
      expect(position).to be_invalid
      expect(position.errors[:start_date]).to include("cannot be more than 6 months in the future")
    end

    it "rejects a duration longer than the max" do
      start_date = Date.current
      position = build_position(start_date:, end_date: start_date + Payroll::Position::MAX_DURATION + 1.day)
      expect(position).to be_invalid
      expect(position.errors[:end_date]).to include("cannot be more than 1 year after the start date")
    end

    it "accepts a valid window" do
      start_date = Date.current
      position = build_position(start_date:, end_date: start_date + 3.months)
      expect(position).to be_valid
    end
  end

  describe "onboarding" do
    let(:position) { create(:payroll_position, aasm_state: :onboarding) }

    describe "#onboarding_checklist" do
      it "lists the steps in the order they happen" do
        keys = position.onboarding_checklist.map { |step| step[:key] }
        expect(keys).to eq(%i[organizer_signature hcb_review tax_form contractor_signature payout_method])
      end

      it "says who each step is waiting on" do
        owners = position.onboarding_checklist.to_h { |step| [step[:key], step[:owner]] }
        expect(owners).to eq(
          organizer_signature: :organizer,
          hcb_review: :hcb,
          tax_form: :contractor,
          contractor_signature: :contractor,
          payout_method: :contractor
        )
      end
    end

    describe "#onboarding_reminder_days" do
      it "nudges frequently at first, then every two weeks" do
        position = build(:payroll_position, start_date: Date.current, end_date: Date.current + 60.days)
        expect(position.onboarding_reminder_days).to eq([1, 2, 7, 14, 28, 42, 56])
      end

      it "stops at the position's end date rather than a fixed deadline" do
        position = build(:payroll_position, start_date: Date.current, end_date: Date.current + 10.days)
        expect(position.onboarding_reminder_days).to eq([1, 2, 7])
      end

      it "schedules nothing for a position that ends today" do
        position = build(:payroll_position, start_date: Date.current - 2.months, end_date: Date.current)
        expect(position.onboarding_reminder_days).to be_empty
      end
    end

    describe "#mark_onboarded" do
      it "cannot transition while an onboarding step is outstanding" do
        allow(position).to receive(:onboarding_complete?).and_return(false)
        expect(position.may_mark_onboarded?).to be(false)
      end

      it "transitions once every onboarding step is complete" do
        allow(position).to receive(:onboarding_complete?).and_return(true)
        expect { position.mark_onboarded! }.to change(position, :aasm_state).from("onboarding").to("onboarded")
      end
    end

    describe "#refresh_onboarding_state!" do
      it "advances an onboarding position to onboarded once complete" do
        allow(position).to receive(:onboarding_complete?).and_return(true)
        position.refresh_onboarding_state!
        expect(position).to be_onboarded
      end

      it "is a no-op while a step is still outstanding" do
        allow(position).to receive(:onboarding_complete?).and_return(false)
        position.refresh_onboarding_state!
        expect(position).to be_onboarding
      end

      it "does not advance a position that is still under review" do
        under_review = create(:payroll_position)
        allow(under_review).to receive(:onboarding_complete?).and_return(true)
        under_review.refresh_onboarding_state!
        expect(under_review).to be_under_review
      end
    end
  end

  describe "#send_contract" do
    let(:payee) { create(:payee) }
    let(:position) { create(:payroll_position, payee:) }
    let(:organizer) { create(:user) }

    before do
      allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
    end

    def stub_docuseal_create(submission_id: "STUBBED")
      stub_request(:post, "https://api.docuseal.co/submissions")
        .to_return(status: 201, body: [{ submission_id: }].to_json, headers: { content_type: "application/json" })
    end

    def stub_docuseal_fetch(submission_id: "STUBBED")
      stub_request(:get, "https://api.docuseal.co/submissions/#{submission_id}")
        .to_return(
          status: 200,
          body: { submitters: [{ role: "HCB", slug: "hcb-slug" }, { role: "Organizer", slug: "organizer-slug" }, { role: "Contractor", slug: "contractor-slug" }] }.to_json,
          headers: { content_type: "application/json" }
        )
    end

    it "creates and sends a contract to DocuSeal" do
      stub_docuseal_create
      stub_docuseal_fetch

      contract = position.send_contract(organizer_user: organizer)

      expect(contract).to be_sent
      expect(contract.party(:organizer).user).to eq(organizer)
    end

    it "voids the newly created contract and re-raises when DocuSeal is unreachable" do
      stub_request(:post, "https://api.docuseal.co/submissions").to_return(status: 500, body: "boom")

      expect { position.send_contract(organizer_user: organizer) }.to raise_error(Faraday::Error)

      contract = position.contracts.sole
      expect(contract).to be_voided
    end

    it "does not leave a stuck contract blocking a subsequent retry" do
      stub_request(:post, "https://api.docuseal.co/submissions").to_return(status: 500, body: "boom")
      expect { position.send_contract(organizer_user: organizer) }.to raise_error(Faraday::Error)
      expect(position.contracts.not_voided).to be_empty

      stub_request(:post, "https://api.docuseal.co/submissions").to_return(status: 201, body: [{ submission_id: "RETRY" }].to_json, headers: { content_type: "application/json" })
      stub_docuseal_fetch(submission_id: "RETRY")

      contract = position.send_contract(organizer_user: organizer)
      expect(contract).to be_sent
    end
  end

  describe "#on_contract_party_signed" do
    let(:payee) { create(:payee) }
    let(:position) { create(:payroll_position, payee:) }
    let(:organizer) { create(:user) }

    before do
      allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))

      stub_request(:post, "https://api.docuseal.co/submissions")
        .to_return(status: 201, body: [{ submission_id: "STUBBED" }].to_json, headers: { content_type: "application/json" })
      stub_request(:get, "https://api.docuseal.co/submissions/STUBBED")
        .to_return(
          status: 200,
          body: { submitters: [{ role: "HCB", slug: "hcb-slug" }, { role: "Organizer", slug: "organizer-slug" }, { role: "Contractor", slug: "contractor-slug" }] }.to_json,
          headers: { content_type: "application/json" }
        )
    end

    it "emails the contractor once HCB signs" do
      contract = position.send_contract(organizer_user: organizer)
      hcb_party = contract.party(:hcb)

      expect { hcb_party.mark_signed! }.to have_enqueued_mail(Payroll::PositionMailer, :onboarding)
    end

    it "does not schedule contract-specific signing reminders for the contractor once HCB signs" do
      contract = position.send_contract(organizer_user: organizer)
      hcb_party = contract.party(:hcb)

      expect { hcb_party.mark_signed! }.not_to have_enqueued_job(Contract::Party::ReminderJob)
    end

    it "schedules onboarding reminders for the contractor once HCB signs" do
      contract = position.send_contract(organizer_user: organizer)
      hcb_party = contract.party(:hcb)

      expect { hcb_party.mark_signed! }
        .to have_enqueued_job(Payroll::Position::OnboardingReminderJob)
        .exactly(position.onboarding_reminder_days.count).times
    end

    it "reports, but does not raise or roll back the signature, when notifying the contractor fails" do
      contract = position.send_contract(organizer_user: organizer)
      hcb_party = contract.party(:hcb)

      allow_any_instance_of(Contract::Party).to receive(:notify).and_raise(StandardError, "queue backend down")
      expect(Rails.error).to receive(:report)

      expect { hcb_party.mark_signed! }.not_to raise_error
      expect(hcb_party.reload).to be_signed
    end
  end

  describe "renewals" do
    let(:payee) { create(:payee) }
    let(:position) do
      create(:payroll_position, payee:, aasm_state: "onboarded", onboarded_at: 1.month.ago,
                                start_date: 1.month.ago.to_date, end_date: 2.months.from_now.to_date)
    end

    def create_renewal(of: position, **attrs)
      of.build_renewal.tap { |renewal| renewal.assign_attributes(attrs) }.tap(&:save!)
    end

    describe "#renewable?" do
      it "is renewable while active or once expired" do
        expect(position).to be_renewable

        position.update!(aasm_state: "expired")
        expect(position).to be_renewable
      end

      %w[under_review onboarding terminated rejected].each do |aasm_state|
        it "is not renewable when #{aasm_state}" do
          position.update!(aasm_state:)
          expect(position).not_to be_renewable
        end
      end

      it "is not renewable again while a renewal is in progress" do
        create_renewal
        expect(position).not_to be_renewable
      end

      it "is not renewable while the renewal would start beyond the usual lead time" do
        position.update_columns(end_date: 7.months.from_now.to_date)
        expect(position).not_to be_renewable

        position.update_columns(end_date: 5.months.from_now.to_date)
        expect(position).to be_renewable
      end

      it "is not renewable once it lapsed too long ago" do
        position.update!(aasm_state: "expired", start_date: 6.months.ago.to_date, end_date: 3.months.ago.to_date)
        expect(position).to be_renewable

        position.update_columns(end_date: (3.months.ago - 1.day).to_date)
        expect(position).not_to be_renewable
      end

      it "is not renewable once its payee is archived" do
        payee.update!(archived_at: Time.current)
        expect(position).not_to be_renewable
      end

      it "is renewable again once a renewal is rejected" do
        create_renewal.update!(aasm_state: "rejected")
        expect(position).to be_renewable
      end
    end

    describe "#build_renewal" do
      it "starts the day after the current contract ends and carries its terms over" do
        renewal = position.build_renewal

        expect(renewal.start_date).to eq(position.end_date + 1.day)
        expect(renewal.end_date - renewal.start_date).to eq(position.end_date - position.start_date)
        expect(renewal).to have_attributes(payee:, title: position.title, rate_cents: position.rate_cents, description: position.description)
      end

      it "starts today when the contract has already expired" do
        position.update!(aasm_state: "expired", start_date: 6.months.ago.to_date, end_date: 3.months.ago.to_date)

        expect(position.build_renewal.start_date).to eq(Date.current)
      end


      it "still limits the renewed term to the max duration" do
        renewal = position.build_renewal
        renewal.end_date = renewal.start_date + 1.year + 1.day

        expect(renewal).to be_invalid
        expect(renewal.errors[:end_date]).to include("cannot be more than 1 year after the start date")
      end

      it "can't overlap the contract it renews" do
        renewal = position.build_renewal
        renewal.start_date = position.end_date

        expect(renewal).to be_invalid
        expect(renewal.errors[:start_date]).to include("must be after the previous contract ends")
      end
    end

    describe ".current" do
      it "lists the renewed contract until its renewal has been signed and started" do
        renewal = create_renewal

        expect(described_class.current).to contain_exactly(position)

        renewal.update!(aasm_state: "onboarded", onboarded_at: Time.current)
        expect(described_class.current).to contain_exactly(position)

        travel_to(renewal.start_date) do
          expect(described_class.current).to contain_exactly(renewal)
        end
      end
    end

    describe "#status" do
      it "shows a signed renewal as upcoming until it starts" do
        renewal = create_renewal
        renewal.update!(aasm_state: "onboarded", onboarded_at: Time.current)

        expect(renewal.status_text).to eq("Upcoming")

        travel_to(renewal.start_date) do
          expect(renewal.status_text).to eq("Active")
        end
      end
    end

    describe "#accepting_invoices?" do
      it "doesn't take invoices on a signed renewal until it starts" do
        renewal = create_renewal
        renewal.update!(aasm_state: "onboarded", onboarded_at: Time.current)

        expect(position).to be_accepting_invoices
        expect(renewal).not_to be_accepting_invoices

        travel_to(renewal.start_date) do
          expect(renewal).to be_accepting_invoices
        end
      end
    end

    describe "#renewal_chain" do
      it "includes every renewal, but not ones that never took effect" do
        create_renewal.update!(aasm_state: "rejected")
        renewal = create_renewal
        renewal.update!(aasm_state: "onboarded", onboarded_at: Time.current)
        second_renewal = create_renewal(of: renewal)

        expect(position.renewal_chain).to eq([position, renewal, second_renewal])
        expect(second_renewal.renewal_chain).to eq([position, renewal, second_renewal])
      end
    end

    describe "#terminate!" do
      it "cancels only an unsigned renewal, leaving the current contract running" do
        renewal = create_renewal(aasm_state: "onboarding")

        expect { renewal.terminate! }.to have_enqueued_mail(Payroll::PositionMailer, :terminated).once

        expect(renewal.reload).to be_terminated
        expect(position.reload).to be_onboarded
      end

      it "leaves the current contract running when a signed renewal is terminated before it starts" do
        renewal = create_renewal
        renewal.update!(aasm_state: "onboarded", onboarded_at: Time.current)

        expect { renewal.terminate! }.to have_enqueued_mail(Payroll::PositionMailer, :terminated).once

        expect(renewal.reload).to be_terminated
        expect(position.reload).to be_onboarded
      end

      it "ends a signed renewal along with the contract it renews, emailing once" do
        renewal = create_renewal
        renewal.update!(aasm_state: "onboarded", onboarded_at: Time.current)

        expect { position.terminate! }.to have_enqueued_mail(Payroll::PositionMailer, :terminated).once

        expect(position.reload).to be_terminated
        expect(renewal.reload).to be_terminated
      end

      it "ends a pending renewal along with the contract it renews" do
        renewal = create_renewal

        position.terminate!

        expect(position.reload).to be_terminated
        expect(renewal.reload).to be_terminated
      end
    end

    describe "#terminatable?" do
      it "is terminatable while it or a renewal of it can still be terminated" do
        renewal = create_renewal
        renewal.update!(aasm_state: "onboarded", onboarded_at: Time.current)
        position.update!(aasm_state: "expired")

        expect(position).to be_terminatable
        expect(renewal).to be_terminatable

        renewal.update!(aasm_state: "terminated")
        expect(position).not_to be_terminatable
      end
    end
  end
end
