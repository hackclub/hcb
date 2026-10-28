# frozen_string_literal: true

require "rails_helper"

# Every email we send should say why the recipient is getting it. Mailer
# actions set @delivery_reason (and optionally @unsubscribe_link), the shared
# footer in layouts/mailer/_footer renders them, and ApplicationMailer#mail
# reports any action that sends without one.
RSpec.describe "mailer delivery reasons", type: :mailer do
  let(:test_mailer_class) do
    Class.new(ApplicationMailer) do
      def self.name = "DeliveryReasonTestMailer"

      def with_reason
        @delivery_reason = "you asked for it."
        @unsubscribe_link = "https://example.com/unsubscribe"
        render_body
      end

      def without_reason
        render_body
      end

      private

      def render_body
        mail(to: "someone@example.com", subject: "Test") do |format|
          format.html { render html: "<p>Body</p>".html_safe, layout: "mailer/default" }
        end
      end
    end
  end

  let(:internal_mailer_class) do
    Class.new(test_mailer_class) do
      def self.name = "InternalTestMailer"

      internal!
    end
  end

  def html_body(mail)
    (mail.html_part || mail).body.decoded
  end

  it "renders the reason and unsubscribe link in the footer" do
    body = html_body(test_mailer_class.with_reason)

    expect(body).to include("You are receiving this email because you asked for it.")
    expect(body).to include('href="https://example.com/unsubscribe"')
    expect(body).to include("If you would like to unsubscribe, please click here.")
  end

  # Rails.error.unexpected raises outside production, so a forgotten reason
  # fails the sending spec instead of reaching an inbox unexplained.
  it "reports an action that sends without a reason" do
    expect { test_mailer_class.without_reason.message }.to raise_error(ActiveSupport::ErrorReporter::UnexpectedError, /DeliveryReasonTestMailer#without_reason/)
  end

  it "lets staff-only mailers send without one and omits both footer lines" do
    body = html_body(internal_mailer_class.without_reason)

    expect(body).not_to include("You are receiving this email because")
    expect(body).not_to include("unsubscribe")
  end

  it "keeps the opt-out on the staff-only mailers only" do
    mailers = Dir.glob("app/mailers/**/*.rb", base: Rails.root).map do |path|
      path.delete_prefix("app/mailers/").delete_suffix(".rb").camelize.constantize
    end
    internal = mailers.select(&:internal_mailer).map(&:name)

    expect(internal).to contain_exactly(
      "AdminMailer",
      "Governance::Admin::Transfer::ApprovalAttemptMailer",
      "MailboxMailer",
      "OrganizerPositionDeletionRequestMailer"
    )
  end
end
