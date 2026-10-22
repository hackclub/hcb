# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::Report, type: :model do
  def build_ach
    LegalEntity::PayoutMethod::AchTransfer.new(account_number: "12345678", routing_number: "021000021")
  end

  describe "validations" do
    context "when backed by a card grant" do
      # The card_grant factory's after_create :transfer_money callback runs
      # DisbursementService::Create, which requires a funded source event.
      # These specs only care about the card_grant FK, not real disbursement
      # mechanics, so we stub the callback the same way spec/models/card_grant_spec.rb does.
      before do
        allow_any_instance_of(CardGrant).to receive(:transfer_money)
      end

      it "rejects event_id changes" do
        source_event = create(:event)
        destination_event = create(:event)
        user = create(:user)
        card_grant = create(:card_grant, event: source_event, user:, sent_by: user)
        report = create(:reimbursement_report, user:, event: source_event, card_grant:)

        report.event = destination_event

        expect(report.valid?(:update)).to be(false)
        expect(report.errors[:base]).to include(/card grant/i)
      end

      it "permits updates that do not change the event" do
        source_event = create(:event)
        user = create(:user)
        card_grant = create(:card_grant, event: source_event, user:, sent_by: user)
        report = create(:reimbursement_report, user:, event: source_event, card_grant:, name: "Old Name")

        report.name = "New Name"

        expect(report.valid?(:update)).to be(true)
      end
    end

    context "when not backed by a card grant" do
      it "permits event_id changes at the model layer" do
        source_event = create(:event)
        destination_event = create(:event)
        user = create(:user)
        report = create(:reimbursement_report, user:, event: source_event)

        report.event = destination_event

        expect(report.valid?(:update)).to be(true)
      end
    end
  end

  describe ".search" do
    let!(:report) do
      user = create(:user, full_name: "Orpheus Dinosaur", email: "orpheus@hackclub.com")
      create(:reimbursement_report, user:, name: "Sticker printing")
    end

    it "matches on the reimbursee's email" do
      expect(described_class.search("orpheus@hackclub.com")).to eq([report])
      expect(described_class.search("@hackclub.com")).to eq([report])
    end

    it "matches on the reimbursee's full name" do
      expect(described_class.search("dinosaur")).to eq([report])
    end

    it "matches on the report name" do
      expect(described_class.search("sticker")).to eq([report])
    end

    it "returns nothing when there's no match" do
      expect(described_class.search("nobody@example.com")).to be_empty
    end
  end

  describe ".in_country" do
    # Phone numbers are stored sanitized (digits only), and the factory's
    # validation would reject made-up numbers, so write them straight to the DB.
    def report_for(phone_number:, currency:)
      user = create(:user)
      user.update_columns(phone_number:)
      create(:reimbursement_report, user:, currency:)
    end

    let!(:us_report) { report_for(phone_number: "14155550123", currency: "USD") }
    let!(:jamaica_report) { report_for(phone_number: "18765550123", currency: "JMD") }
    let!(:germany_report) { report_for(phone_number: "4915123456789", currency: "EUR") }
    let!(:spain_report) { report_for(phone_number: "34612345678", currency: "EUR") }
    let!(:german_user_usd_report) { report_for(phone_number: "4915198765432", currency: "USD") }

    it "doesn't match on a calling code shared with other countries" do
      expect(described_class.in_country("JM")).to contain_exactly(jamaica_report)
    end

    it "matches on the calling code alone when the currency is shared but the calling code isn't" do
      expect(described_class.in_country("DE")).to contain_exactly(germany_report, german_user_usd_report)
      expect(described_class.in_country("ES")).to contain_exactly(spain_report)
    end

    it "falls back to the currency when neither the calling code nor the currency is unique" do
      expect(described_class.in_country("US")).to contain_exactly(us_report, german_user_usd_report)
    end

    it "returns nothing for an unknown country" do
      expect(described_class.in_country("ZZ")).to be_empty
    end
  end

  describe ".countries_for_filter" do
    it "lists every widely recognized country as a [name, alpha2] pair" do
      countries = described_class.countries_for_filter

      expect(countries.size).to eq(described_class::WIDELY_RECOGNIZED_COUNTRY_CODES.size)
      expect(countries.map(&:last)).to match_array(described_class::WIDELY_RECOGNIZED_COUNTRY_CODES)
      expect(countries.map(&:first)).to eq(countries.map(&:first).sort_by { |name| I18n.transliterate(name) })
    end
  end

  describe "payout method association" do
    let(:user) { create(:user) }

    describe "setting the payout method on create" do
      it "sets the user's default payout method on the report" do
        pm = user.personal_legal_entity.payout_methods.create!(default: true, details: build_ach)

        report = create(:reimbursement_report, user:)

        expect(report.legal_entity_payout_method).to eq(pm)
        expect(report.payout_method).to eq(pm)
      end

      it "leaves the column null when the user has no default" do
        report = create(:reimbursement_report, user:)

        expect(report.legal_entity_payout_method).to be_nil
      end

      it "does not overwrite an explicitly-assigned payout method" do
        default_pm = user.personal_legal_entity.payout_methods.create!(default: true, details: build_ach)
        other_pm = user.personal_legal_entity.payout_methods.create!(default: false, details: build_ach)

        report = create(:reimbursement_report, user:, legal_entity_payout_method: other_pm)

        expect(report.legal_entity_payout_method).to eq(other_pm)
        expect(report.legal_entity_payout_method).not_to eq(default_pm)
      end
    end

    describe "#payout_method" do
      it "returns the method set on the report even after the user's default changes" do
        original_pm = user.personal_legal_entity.payout_methods.create!(default: true, details: build_ach)
        report = create(:reimbursement_report, user:)

        user.personal_legal_entity.payout_methods.create!(default: true, details: build_ach)

        expect(report.reload.payout_method).to eq(original_pm)
      end
    end
  end

  describe "the invitation email" do
    it "is sent when somebody else invited the user" do
      inviter = create(:user)

      expect {
        create(:reimbursement_report, user: create(:user), inviter:)
      }.to have_enqueued_mail(ReimbursementMailer, :invitation)
    end

    it "is not sent when the user created the report themselves" do
      user = create(:user)

      expect {
        create(:reimbursement_report, user:, inviter: user)
      }.not_to have_enqueued_mail(ReimbursementMailer, :invitation)
    end

    # Eventless draft reports come in from Discord, SMS, and email, and the
    # invitation email is event-scoped from its subject line down. Enqueuing it
    # for one raised NoMethodError on nil in the mail delivery job.
    it "is not sent for an eventless draft report" do
      expect {
        create(:reimbursement_report, user: create(:user), event: nil, inviter: nil)
      }.not_to have_enqueued_mail(ReimbursementMailer, :invitation)
    end
  end
end
