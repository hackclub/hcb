# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocumentsController do
  include SessionSupport
  render_views

  def create_document(event: nil)
    Document.create!(
      event:,
      user: create(:user, :make_admin),
      name: "Determination letter",
      file: Rack::Test::UploadedFile.new(file_fixture("attachment1.txt"), "text/plain")
    )
  end

  def action_labels
    response.parsed_body.css("h1.heading a.btn").map { |link| link.text.squish }
  end

  describe "#show" do
    it "shows auditors a common document's page with only the download action" do
      document = create_document
      create_session(create(:user, :make_auditor), verified: true)

      get(:show, params: { id: document.slug })

      expect(response).to have_http_status(:ok)
      expect(action_labels).to eq(["Download"])
    end

    it "shows admins every document action" do
      document = create_document
      create_session(create(:user, :make_admin), verified: true)

      get(:show, params: { id: document.slug })

      expect(response).to have_http_status(:ok)
      expect(action_labels).to eq(["Download", "Edit", "Archive", "Destroy"])
    end

    it "sends organizers straight to a common document's download" do
      document = create_document
      reader = create(:user)
      create(:organizer_position, user: reader, role: :reader)
      create_session(reader, verified: true)

      get(:show, params: { id: document.slug })

      expect(response).to redirect_to(document_download_path(document))
    end

    it "only offers auditors an archived document's download" do
      document = create_document
      document.mark_archive!(create(:user, :make_admin))
      create_session(create(:user, :make_auditor), verified: true)

      get(:show, params: { id: document.slug })

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.at_css(".banner--archived").text).not_to include("unarchive it")
      expect(action_labels).to eq(["Download"])
    end
  end
end
