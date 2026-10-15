# frozen_string_literal: true

require "rails_helper"

RSpec.describe "public_activity/raw_pending_stripe_transaction/_create", type: :view do
  let(:event) { create(:event) }
  let(:card) { create(:stripe_card, :with_stripe_id, event:) }
  let(:viewer) { create(:user) }
  let(:hcb_code) { instance_double(HcbCode, stripe_refund?: false, pt: pending_transaction, event:, memo: "GOOGLE *INSTAGRAM", to_param: "test", amount_cents: -1623) }
  let(:pending_transaction) { instance_double(CanonicalPendingTransaction, declined?: true) }
  let(:transaction) { instance_double(RawPendingStripeTransaction, canonical_pending_transaction: pending_transaction, stripe_card: card, amount_cents: -1623) }
  let(:activity) { PublicActivity::Activity.new(owner: card.user, created_at: 1.hour.ago) }

  before do
    allow(pending_transaction).to receive(:local_hcb_code).and_return(hcb_code)
    allow(activity).to receive(:trackable).and_return(transaction)
    allow(transaction).to receive(:try).with(:hcb_code).and_return(nil)
  end

  def render_activity(current_viewer = viewer)
    controller = EventsController.new
    controller.set_request!(ActionDispatch::TestRequest.create)
    allow(controller).to receive(:current_user).and_return(current_viewer)
    html = controller.view_context.render(
      partial: "public_activity/raw_pending_stripe_transaction/create",
      locals: { activity:, p: { current_user: current_viewer } }
    )
    Nokogiri::HTML.fragment(html)
  end

  it "links the specific card for organization readers and leaves the transaction link intact" do
    create(:organizer_position, user: viewer, event:, role: :reader)

    document = render_activity
    link = document.at_css("a[href='#{stripe_card_path(card)}']")
    expect(link["aria-label"]).to eq("View card")
    expect(link["title"]).to be_nil
    expect(link.at_css("svg")).to be_present
    expect(link.parent.at_css(".timestamp")).to be_present
    expect(document.css("a").map(&:text)).not_to include("card")
    expect(link["data-turbo-frame"]).to eq("_top")
    expect(document.at_css("a[href='#{hcb_code_path(hcb_code)}']")).to be_present
  end

  it "leaves card as plain text for unrelated users" do
    document = render_activity
    expect(document.at_css("a[aria-label='View card']")).to be_nil
    expect(document.text.squish).to include("card was declined for $16.23")
  end

  it "leaves card as plain text for anonymous viewers" do
    expect(render_activity(nil).at_css("a[aria-label='View card']")).to be_nil
  end

  it "renders missing cards without a broken link" do
    allow(transaction).to receive(:stripe_card).and_return(nil)
    document = render_activity
    expect(document.text.squish).to include("card was declined for $16.23")
    expect(document.at_css("a[aria-label='View card']")).to be_nil
  end
end
