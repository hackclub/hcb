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

  describe "sensitive messages" do
    let(:code) { "481-209" }
    let!(:sensitive) do
      Ahoy::Message.create!(
        subject: "HCB Login Code: #{code}",
        mailer: "LoginCodeMailer#send_code",
        sensitive: true,
        sent_at: 1.minute.ago,
        content: Mail.new do
          to "someone@example.invalid"
          subject "HCB Login Code: 481-209"
          text_part { body "Your code is 481-209" }
          html_part do
            content_type "text/html; charset=UTF-8"
            body "<p>Your code is 481-209</p>"
          end
        end.encoded
      )
    end

    def sign_in_as(user, impersonated_by: nil)
      session = create(:user_session, user:, verified: true, expiration_at: 1.hour.from_now, impersonated_by:)

      allow_any_instance_of(SessionsHelper)
        .to receive(:find_current_session)
        .and_return(session)
    end

    it "denies an auditor the contents" do
      sign_in_as(create(:user, :make_auditor))

      get "/admin/email_html", params: { message_id: sensitive.id }

      expect(response).to have_http_status(:forbidden)
    end

    it "denies an admin the contents" do
      sign_in_as(create(:user, :make_admin))

      get "/admin/email_html", params: { message_id: sensitive.id }

      expect(response).to have_http_status(:forbidden)
    end

    it "denies an admin impersonating a superadmin" do
      sign_in_as(create(:user, access_level: :superadmin), impersonated_by: create(:user, :make_admin))

      get "/admin/email_html", params: { message_id: sensitive.id }

      expect(response).to have_http_status(:forbidden)
    end

    it "allows a superadmin the contents" do
      sign_in_as(create(:user, access_level: :superadmin))

      get "/admin/email_html", params: { message_id: sensitive.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(code)
    end

    it "denies the iframe wrapper to an auditor" do
      sign_in_as(create(:user, :make_auditor))

      get "/admin/email", params: { message_id: sensitive.id }

      expect(response).to have_http_status(:forbidden)
    end

    it "hides the subject from an auditor and names the mailer instead" do
      sign_in_as(create(:user, :make_auditor))

      get "/admin/emails"

      expect(response.body).not_to include(code)
      expect(response.body).to include("LoginCodeMailer#send_code")
    end

    it "does not link an auditor to the restricted contents" do
      sign_in_as(create(:user, :make_auditor))

      get "/admin/emails"

      expect(listed_ids).not_to include(sensitive.id)
    end

    it "shows the subject to a superadmin" do
      sign_in_as(create(:user, access_level: :superadmin))

      get "/admin/emails"

      expect(response.body).to include(code)
      expect(listed_ids).to include(sensitive.id)
    end

    it "still serves a non-sensitive message to an auditor" do
      ordinary = Ahoy::Message.create!(
        subject: "Upload a receipt",
        mailer: "ReceiptBinMailer#bounce_success",
        sent_at: 1.minute.ago
      )
      sign_in_as(create(:user, :make_auditor))

      get "/admin/email", params: { message_id: ordinary.id }

      expect(response).to have_http_status(:ok)
    end
  end
end
