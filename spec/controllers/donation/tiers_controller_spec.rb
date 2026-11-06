# frozen_string_literal: true

require "rails_helper"

RSpec.describe Donation::TiersController do
  include SessionSupport

  let(:event) { create(:event) }
  let(:other_event) { create(:event) }
  let!(:tier) { event.donation_tiers.create!(name: "Supporter", amount_cents: 10_00) }
  let!(:other_tier) { other_event.donation_tiers.create!(name: "Sponsor", amount_cents: 50_00) }

  def update_tiers(tiers)
    patch :update, params: { event_id: event.slug, tiers: }
  end

  describe "#update" do
    context "as a manager" do
      before do
        user = create(:user)
        create(:organizer_position, user:, event:, role: :manager)
        create_session(user, verified: true)
      end

      it "does not update a tier belonging to another organization" do
        update_tiers(
          tier.id       => { name: "Renamed", amount_cents: "20", published: "1" },
          other_tier.id => { name: "Hijacked", amount_cents: "1", published: "1" },
        )

        expect(response).to have_http_status(:ok)
        expect(tier.reload).to have_attributes(name: "Renamed", amount_cents: 20_00, published: true)
        expect(other_tier.reload).to have_attributes(name: "Sponsor", amount_cents: 50_00, published: false)
      end
    end

    context "as a reader" do
      before do
        user = create(:user)
        create(:organizer_position, user:, event:, role: :reader)
        create_session(user, verified: true)
      end

      it "does not update any tiers" do
        update_tiers(tier.id => { name: "Renamed", amount_cents: "20", published: "1" })

        expect(tier.reload).to have_attributes(name: "Supporter", amount_cents: 10_00, published: false)
      end
    end
  end
end
