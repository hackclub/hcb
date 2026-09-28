# frozen_string_literal: true

require "rails_helper"

RSpec.describe HcbCodesController do
  include SessionSupport
  render_views

  let(:event) { create(:event) }
  let(:user) { create(:user) }
  let(:cpt) { create(:canonical_pending_transaction) }
  let(:hcb_code) { cpt.local_hcb_code }

  before do
    create(:canonical_pending_event_mapping, canonical_pending_transaction: cpt, event:)
    create(:organizer_position, user:, event:)
    create_session(user, verified: true)
    request.headers["Turbo-Frame"] = "shared_popover_body"
  end

  # What the flash hash carries into the *next* request.
  def flash_carried_over
    session["flash"].to_h["flashes"]
  end

  it "renders the flash inside the frame and doesn't repeat it on the next page" do
    get(:edit, params: { id: hcb_code.hashid }, flash: { success: "Marked no/lost receipt on that transaction." })

    expect(response.body).to include("Marked no/lost receipt on that transaction.")
    expect(flash_carried_over).to be_blank
  end

  it "keeps the flash on a frame response that never renders it" do
    get(:edit, params: { id: hcb_code.hashid, inline: "true" }, flash: { success: "Marked no/lost receipt on that transaction." })

    expect(response.body).not_to include("Marked no/lost receipt on that transaction.")
    expect(flash_carried_over).to include("success" => "Marked no/lost receipt on that transaction.")
  end
end
