# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoicePolicy, type: :policy do
  describe "#index?" do
    let(:user) { create(:user) }
    let(:event) { create(:event, is_public: false) }

    before do
      allow_any_instance_of(Sponsor).to receive(:create_stripe_customer).and_return(true)
      create(:organizer_position, user:, event:)
      create(:invoice, sponsor: create(:sponsor, event:))
    end

    def index?(invoices)
      described_class.new(user, invoices).index?
    end

    it "allows an organizer to list their organization's invoices" do
      expect(index?(Invoice.all)).to be_truthy
    end

    it "does not allow a non-organizer to list a private organization's invoices" do
      other_event = create(:event, is_public: false)
      create(:invoice, sponsor: create(:sponsor, event: other_event))

      expect(index?(Invoice.joins(:sponsor).where(sponsors: { event: other_event }))).to be_falsey
    end

    it "does not allow listing invoices spanning multiple private organizations" do
      create(:invoice, sponsor: create(:sponsor, event: create(:event, is_public: false)))

      expect(index?(Invoice.all)).to be_falsey
    end
  end
end
