# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API v4 invoices", type: :request do
  before do
    allow_any_instance_of(Sponsor).to receive(:create_stripe_customer)
  end

  let(:event) { create(:event, plan_type: Event::Plan::Standard) }

  def list_invoices(user)
    token = create(:api_token, user:)
    get "/api/v4/invoices", params: { event_id: event.public_id }, headers: { "Authorization" => "Bearer #{token.token}" }
  end

  def add_reader(user, to: event)
    create(:organizer_position, event: to, user:, role: :reader)
    user
  end

  describe "GET /api/v4/invoices" do
    it "returns an empty list to a reader of an organization without invoices" do
      list_invoices(add_reader(create(:user)))

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "returns the invoices to a reader of a private organization's parent" do
      parent = create(:event, plan_type: Event::Plan::Standard)
      event.update!(parent:)
      event.update_column(:is_public, false)
      invoice = create(:invoice, sponsor: create(:sponsor, event:))

      list_invoices(add_reader(create(:user), to: parent))

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.sole).to include("id" => invoice.public_id, "item_description" => invoice.item_description)
    end

    it "returns existing invoices when the plan no longer includes invoicing" do
      invoice = create(:invoice, sponsor: create(:sponsor, event:))
      event.plan.update!(type: Event::Plan::CardsOnly.name)

      list_invoices(add_reader(create(:user)))

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck("id")).to eq([invoice.public_id])
    end

    it "forbids a reader when the plan excludes invoicing and there are no invoices" do
      event.plan.update!(type: Event::Plan::CardsOnly.name)

      list_invoices(add_reader(create(:user)))

      expect(response).to have_http_status(:forbidden)
    end

    it "forbids a user outside a private organization" do
      event.update_column(:is_public, false)
      create(:invoice, sponsor: create(:sponsor, event:))

      list_invoices(create(:user))

      expect(response).to have_http_status(:forbidden)
    end

    it "hides invoice details from a user outside a transparent organization" do
      event.update!(is_public: true)
      create(:invoice, sponsor: create(:sponsor, event:))

      list_invoices(create(:user))

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.sole).not_to include("item_description", "sponsor_id")
    end
  end
end
