# frozen_string_literal: true

require "rails_helper"

RSpec.describe "card_grant/pre_authorizations/_screenshot_list" do
  let(:event) { create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate) }
  let(:card_grant) { create(:card_grant, event:) }
  let(:pre_authorization) { card_grant.pre_authorization || card_grant.create_pre_authorization! }

  def render_list
    render partial: "card_grant/pre_authorizations/screenshot_list", locals: { screenshots: pre_authorization.screenshots }
    rendered
  end

  it "opens image screenshots in a modal when clicked" do
    pre_authorization.screenshots.attach(io: File.open(Rails.root.join("spec/fixtures/files/receipt.png")), filename: "cart.png", content_type: "image/png")

    html = Nokogiri::HTML(render_list)
    screenshot = pre_authorization.screenshots.first

    thumbnail = html.at_css("img[data-behavior='modal_trigger']")
    expect(thumbnail).to be_present
    expect(thumbnail["data-modal"]).to eq("preview_screenshot_#{screenshot.id}")

    modal = html.at_css("##{thumbnail["data-modal"]}[data-behavior='modal']")
    expect(modal).to be_present
    expect(modal.at_css("img")["src"]).to eq(thumbnail["src"])
  end

  it "links non-image screenshots to the file itself" do
    pre_authorization.screenshots.attach(io: StringIO.new("%PDF-1.4"), filename: "cart.pdf", content_type: "application/pdf")

    html = Nokogiri::HTML(render_list)

    expect(html.at_css("[data-behavior='modal_trigger']")).to be_nil
    link = html.at_css("a[target='_blank']")
    expect(link).to be_present
    expect(link["href"]).to include("cart.pdf")
    expect(link.text).to include("cart.pdf")
  end

  it "shows a blankslate when there are no screenshots" do
    expect(render_list).to include("No screenshots uploaded")
  end
end
