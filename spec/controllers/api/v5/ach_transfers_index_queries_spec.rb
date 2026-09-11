# frozen_string_literal: true

require "rails_helper"

# Attribute-level authorization runs per record, so a policy that asks the
# database a question is a query per row. Both role checks in
# AchTransferPolicy used to do exactly that (a recursive CTE plus an
# organizer_positions lookup, four queries per row, even for signed-out
# visitors). This pins the property that fixed it: query count must not grow
# with the size of the page.
RSpec.describe Api::V5::AchTransfersController do
  render_views

  before do
    allow_any_instance_of(UsersHelper).to receive(:profile_picture_for).and_return("https://gravatar.com/avatar/stubbed")
  end

  def queries_rendering(rows)
    event = create(:event, :with_positive_balance, is_public: true)
    rows.times { create(:ach_transfer, event:, creator: create(:user)) }

    count = 0
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      count += 1 unless payload[:name].to_s.match?(/SCHEMA|TRANSACTION/)
    end
    # Filtered to this organization so the two measurements stay independent —
    # otherwise the second call also lists the first call's rows.
    get :index, params: { organization_id: event.public_id }, as: :json
    ActiveSupport::Notifications.unsubscribe(subscription)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["data"].size).to eq(rows)
    count
  end

  it "issues the same number of queries for a large page as a small one" do
    small = queries_rendering(2)
    large = queries_rendering(10)

    expect(large).to eq(small)
  end

end
