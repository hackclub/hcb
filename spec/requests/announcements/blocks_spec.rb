# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Announcements::BlocksController", type: :request do
  let(:event) { create(:event) }
  let(:author) { create(:user) }
  let(:announcement) { Announcement.create!(event:, author:, title: "Update", content: {}) }
  let(:block) { Announcement::Block::DonationSummary.create!(announcement:, parameters: { "start_date" => "2026-01-01", "end_date" => "2026-02-01" }) }

  def sign_in_as(user)
    allow_any_instance_of(SessionsHelper).to receive(:find_current_session).and_return(create(:user_session, user:))
  end

  def get_edit = get edit_announcements_block_path(block), headers: { "Accept" => "text/vnd.turbo-stream.html" }

  before { create(:organizer_position, user: author, event:, role: :manager) }

  describe "GET edit" do
    it "appends the block's editor as a modal that opens itself, apart from the insert modal" do
      sign_in_as(author)

      get_edit

      stream = Nokogiri::HTML5.fragment(response.body).at_css("turbo-stream[action=append][targets=body]")
      dialog = stream.at_css("template").children.at_css("dialog")
      expect(dialog["id"]).to eq("edit_announcement_block_donation_summary_#{block.id}")
      expect(dialog["data-controller"].split).to contain_exactly("announcement-modal", "open-modal")
      expect(dialog["data-announcement-modal-block-id-value"]).to eq(block.id.to_s)
    end

    it "streams nothing to a manager who didn't write the announcement" do
      other_manager = create(:user)
      create(:organizer_position, user: other_manager, event:, role: :manager)
      sign_in_as(other_manager)

      get_edit

      expect(response).to redirect_to(root_path)
      expect(response.body).not_to include("dialog")
    end
  end
end
