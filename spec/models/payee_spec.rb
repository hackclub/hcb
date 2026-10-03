# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payee, type: :model do
  describe "validations" do
    describe "uniqueness of legal_entity_id scoped to event_id" do
      let(:event) { create(:event) }
      let(:legal_entity) { create(:legal_entity) }

      it "is valid when the legal entity is not yet linked to the event" do
        payee = build(:payee, event:, legal_entity:)
        expect(payee).to be_valid
      end

      it "is invalid when the same legal entity is linked to the same event twice" do
        create(:payee, event:, legal_entity:)
        duplicate = build(:payee, event:, legal_entity:)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:legal_entity_id]).to include("has already been taken")
      end

      it "allows the same legal entity to be linked to different events" do
        other_event = create(:event)
        create(:payee, event:, legal_entity:)
        payee = build(:payee, event: other_event, legal_entity:)

        expect(payee).to be_valid
      end

      it "allows different legal entities to be linked to the same event" do
        other_legal_entity = create(:legal_entity)
        create(:payee, event:, legal_entity:)
        payee = build(:payee, event:, legal_entity: other_legal_entity)

        expect(payee).to be_valid
      end
    end
  end

  describe "changing the email of a payee with an onboarding contract" do
    include ActiveJob::TestHelper

    let(:payee) { create(:payee, legal_entity: nil) }
    let(:position) { create(:payroll_position, payee:) }
    let(:organizer) { create(:user) }

    before do
      allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
      allow_any_instance_of(Contract).to receive(:send_using_docuseal!)
      allow_any_instance_of(Contract).to receive(:archive_on_docuseal!)
      position.send_contract(organizer_user: organizer)
      position.update_columns(aasm_state: "onboarding")
    end

    it "reissues the contract, emails the organizer, and returns the position to review" do
      old_contract = position.contract

      perform_enqueued_jobs do
        payee.update!(email: "new@example.com")
      end

      delivered = ActionMailer::Base.deliveries.select { |m| m.subject.include?("issue in the agreement") }
      expect(delivered.map(&:to)).to eq([[organizer.email]])

      expect(old_contract.reload).to be_voided
      new_contract = position.reload.contract
      expect(new_contract.party(:contractor).email).to eq("new@example.com")
      expect(position).to be_under_review
      expect(payee.organizer_resign_position).to eq(position)

      mail = Contract::PartyMailer.with(party: new_contract.party(:organizer), message: +"hi").reissued
      expect(mail.to).to eq([organizer.email])
      expect(mail.body.encoded).to include("sign a new agreement")
    end
  end
end
