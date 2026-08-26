# frozen_string_literal: true

require "rails_helper"

# Covers the /admin/event_new form: it posts a hand-rolled set of param names
# (no model), so a renamed field would silently stop reaching EventService::Create.
RSpec.describe AdminController, type: :controller do
  include SessionSupport

  let!(:admin) { create(:user, :make_admin) }
  before { create_session(admin, verified: true) }

  # Exactly what the redesigned form submits.
  def form_params(**overrides)
    {
      name: "Scrapyard Vermont",
      organizer_email: "",
      is_signee: "true",
      cosigner_email: "",
      include_videos: "0",
      country: "US",
      plan: Event::Plan::Standard.name,
      "tags" => ["", "Climate", "Hackathon"],
      point_of_contact_id: admin.id,
      risk_level: "",
      is_public: "1",
      approved: "1",
      demo_mode: "0",
    }.merge(overrides)
  end

  it "creates the org with tags from the pill checkboxes" do
    expect { post :event_create, params: form_params }.to change(Event, :count).by(1)
    expect(flash[:success]).to include("Scrapyard Vermont")

    event = Event.order(:created_at).last
    expect(event.name).to eq("Scrapyard Vermont")
    expect(event.country).to eq("US")
    expect(event.event_tags.map(&:name)).to contain_exactly("Climate", "Hackathon")
    expect(event.is_public).to be(true)
    expect(event.demo_mode).to be(false)
    expect(event.point_of_contact_id).to eq(admin.id)
  end

  it "creates the org when no tags are checked (only the blank hidden field)" do
    expect { post :event_create, params: form_params("tags" => [""]) }.to change(Event, :count).by(1)
    expect(Event.order(:created_at).last.event_tags).to be_empty
  end

  it "invites the organizer as a contract signee with a cosigner" do
    # Sending the contract itself talks to Airtable/Docuseal; we only care that
    # the form's contract fields reach it intact.
    expect_any_instance_of(OrganizerPositionInvite)
      .to receive(:send_contract)
      .with(cosigner_email: "guardian@hackclub.com", include_videos: true)

    post :event_create, params: form_params(
      organizer_email: "orpheus@hackclub.com",
      is_signee: "true",
      cosigner_email: "guardian@hackclub.com",
      include_videos: "1"
    )

    invite = Event.order(:created_at).last.organizer_position_invites.last
    expect(invite.user.email).to eq("orpheus@hackclub.com")
    expect(invite.is_signee).to be(true)
  end

  it "invites a non-signee organizer" do
    post :event_create, params: form_params(organizer_email: "orpheus@hackclub.com", is_signee: "false")

    invite = Event.order(:created_at).last.organizer_position_invites.last
    expect(invite.is_signee).to be(false)
  end

  it "honours the unchecked settings and a chosen risk level" do
    post :event_create, params: form_params(is_public: "0", approved: "0", demo_mode: "1", risk_level: "high")
    event = Event.order(:created_at).last
    expect(event.is_public).to be(false)
    expect(event.demo_mode).to be(true)
    expect(event.risk_level).to eq("high")
  end
end
