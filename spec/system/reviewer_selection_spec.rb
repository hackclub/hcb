# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reviewer selection", type: :system do
  let(:manager) { create(:user) }

  def reveal_submit_modal_and_screenshot(path)
    page.execute_script("document.getElementById('submit').style.display = 'block'")
    page.save_screenshot(path, selector: "#submit")
  end

  before do
    driven_by :cuprite, screen_size: [1400, 1400], options: {
      timeout: 15,
      process_timeout: 60,
      js_errors: true,
      url_whitelist: [/\Ahttp:\/\/127\.0\.0\.1:\d+\//],
      browser_options: { "no-sandbox" => nil }
    }

    allow_any_instance_of(SessionsHelper)
      .to receive(:find_current_session)
      .and_return(create(:user_session, user: manager))
  end

  it "shows the grant settings toggle" do
    event = create(:event, plan_type: Event::Plan::HackClubAffiliate)
    create(:organizer_position, event:, user: manager, role: :manager)
    CardGrantSetting.find_or_create_by!(event:)

    visit "/#{event.slug}/settings/card_grants"

    page.execute_script("document.querySelector('.welcome')?.remove()")
    expect(page).to have_content("Let grant recipients pick a reviewer")

    page.execute_script("document.evaluate(\"//div[contains(@class, 'field--checkbox')][.//span[contains(., 'pick a reviewer')]]\", document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue.scrollIntoView({ block: 'center' })")
    page.save_screenshot("/tmp/opencode/grant_settings.png", full: true)
  end

  it "hides the reviewer picker on a card grant report when the org has not enabled it" do
    allow_any_instance_of(CardGrant).to receive(:transfer_money)
    recipient = create(:user)
    event = create(:event)
    create(:organizer_position, event:, user: manager, role: :manager)
    card_grant = create(:card_grant, event:, user: recipient, sent_by: manager)
    report = create(:reimbursement_report, user: recipient, event:, card_grant:)

    allow_any_instance_of(SessionsHelper)
      .to receive(:find_current_session)
      .and_return(create(:user_session, user: recipient))

    visit reimbursement_report_path(report)

    expect(page).to have_content("Test Report")
    expect(page).to have_no_select("reviewer_id", visible: :all)
    reveal_submit_modal_and_screenshot("/tmp/opencode/card_grant_report.png")
  end

  it "shows the reviewer picker on a card grant report when the org has enabled it" do
    allow_any_instance_of(CardGrant).to receive(:transfer_money)
    recipient = create(:user)
    event = create(:event)
    create(:organizer_position, event:, user: manager, role: :manager)
    event.update!(reimbursement_reviewer_selection: :optional)
    card_grant = create(:card_grant, event:, user: recipient, sent_by: manager)
    event.card_grant_setting.update!(reviewer_selection_enabled: true)
    report = create(:reimbursement_report, user: recipient, event:, card_grant:)

    allow_any_instance_of(SessionsHelper)
      .to receive(:find_current_session)
      .and_return(create(:user_session, user: recipient))

    visit reimbursement_report_path(report)

    expect(page).to have_select("reviewer_id", visible: :all)
    reveal_submit_modal_and_screenshot("/tmp/opencode/card_grant_report_enabled.png")
  end
end
