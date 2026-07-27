# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payroll::Position, type: :model do
  describe "#status" do
    {
      "under_review" => :onboarding,
      "onboarding"   => :onboarding,
      "onboarded"    => :active,
      "expired"      => :completed,
      "terminated"   => :completed,
      "rejected"     => :completed,
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

    it "shows a single month when there is no end date" do
      position = described_class.new(start_date: Date.new(2026, 4, 1))
      expect(position.period_label).to eq("Apr 2026")
    end

    it "collapses to a single month when start and end fall in the same month" do
      position = described_class.new(start_date: Date.new(2026, 4, 1), end_date: Date.new(2026, 4, 28))
      expect(position.period_label).to eq("Apr 2026")
    end

    it "shows a range within the same year" do
      position = described_class.new(start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 6, 30))
      expect(position.period_label).to eq("Jan–Jun 2026")
    end

    it "spans years when start and end fall in different years" do
      position = described_class.new(start_date: Date.new(2025, 12, 1), end_date: Date.new(2026, 2, 28))
      expect(position.period_label).to eq("Dec 2025–Feb 2026")
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
      it "includes a step for the organizer signing the contract" do
        labels = position.onboarding_checklist.map { |step| step[:label] }
        expect(labels).to include("Contract signed by organizer")
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

    it "schedules signing reminders for the contractor once HCB signs" do
      contract = position.send_contract(organizer_user: organizer)
      hcb_party = contract.party(:hcb)

      expect { hcb_party.mark_signed! }.to have_enqueued_job(Contract::Party::ReminderJob).at_least(:once)
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
end
