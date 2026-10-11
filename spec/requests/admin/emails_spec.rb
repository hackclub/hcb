# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /admin/emails", type: :request do
  let(:admin) { create(:user, :make_admin) }

  before do
    admin_session = create(:user_session, user: admin, verified: true, expiration_at: 1.hour.from_now)

    allow_any_instance_of(SessionsHelper)
      .to receive(:find_current_session)
      .and_return(admin_session)
  end

  # Ordered so that neither `id` nor insertion order matches `sent_at desc`.
  let!(:oldest) { Ahoy::Message.create!(subject: "Upload a receipt", sent_at: 3.days.ago) }
  let!(:newest) { Ahoy::Message.create!(subject: "Upload a receipt", sent_at: 1.hour.ago) }
  let!(:middle) { Ahoy::Message.create!(subject: "Upload a receipt", sent_at: 1.day.ago) }

  # The rendered row order, taken from each row's modal trigger.
  def listed_ids
    response.body.scan(/data-modal="message_(\d+)"/).flatten.map(&:to_i)
  end

  it "lists emails newest first" do
    get "/admin/emails"

    expect(response).to have_http_status(:ok)
    expect(listed_ids).to eq([newest.id, middle.id, oldest.id])
  end

  it "lists search results newest first" do
    get "/admin/emails", params: { q: "receipt" }

    expect(response).to have_http_status(:ok)
    expect(listed_ids).to eq([newest.id, middle.id, oldest.id])
  end
end
