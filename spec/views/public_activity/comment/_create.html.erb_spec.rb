# frozen_string_literal: true

require "rails_helper"

RSpec.describe "public_activity/comment/_create" do
  let(:user) { create(:user, :make_admin) }
  let(:event) { create(:event) }

  before do
    def view.current_user = nil
  end

  def render_comment(commentable)
    comment = create(:comment, commentable:, user:)
    activity = PublicActivity::Activity.create!(trackable: comment, key: "comment.create", owner: user)

    render partial: "public_activity/comment/create", locals: { activity:, p: {}, current_user: user }
    [comment, Nokogiri::HTML(rendered)]
  end

  it "links a comment on an HCB code to the HCB code's ledger item" do
    cpt = create(:canonical_pending_transaction, event:, memo: "Lunch")
    ledger_item = cpt.reload.ledger_item

    comment, html = render_comment(cpt.local_hcb_code)
    hrefs = html.css("a").map { |a| a["href"] }

    expect(html.text.squish).to include("You commented on Lunch")
    expect(hrefs).to include(ledger_item_url(ledger_item, anchor: "comment-#{comment.hashid}"))
    expect(hrefs).to include(ledger_item_path(ledger_item))
    expect(hrefs).not_to include(a_string_matching(/\/hcb\//))
  end

  it "still links other commentables to themselves" do
    comment, html = render_comment(event)
    hrefs = html.css("a").map { |a| a["href"] }

    expect(html.text.squish).to include("You commented on #{event.name}")
    expect(hrefs).to include(event_url(event, anchor: "comment-#{comment.hashid}"))
  end
end
