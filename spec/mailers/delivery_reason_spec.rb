# frozen_string_literal: true

require "rails_helper"

# Every email we send should say why the recipient is getting it. Mailer
# actions set @delivery_reason (and optionally @unsubscribe_link) and the shared
# footer in layouts/mailer/_footer renders them.
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

  def html_body(mail)
    (mail.html_part || mail).body.decoded
  end

  it "renders the reason and unsubscribe link in the footer" do
    body = html_body(test_mailer_class.with_reason)

    expect(body).to include("You are receiving this email because you asked for it.")
    expect(body).to include('href="https://example.com/unsubscribe"')
    expect(body).to include("If you would like to unsubscribe, please click here.")
  end

  it "omits both lines when the action doesn't set them" do
    body = html_body(test_mailer_class.without_reason)

    expect(body).not_to include("You are receiving this email because")
    expect(body).not_to include("unsubscribe")
  end

  # Mailers that only ever reach HCB staff. Everything else is user-facing and
  # must explain itself.
  let(:internal_mailers) do
    %w[
      app/mailers/application_mailer.rb
      app/mailers/admin_mailer.rb
      app/mailers/governance/admin/transfer/approval_attempt_mailer.rb
      app/mailers/mailbox_mailer.rb
      app/mailers/organizer_position_deletion_request_mailer.rb
    ]
  end

  it "is set by every user-facing mailer" do
    mailers = Dir.glob("app/mailers/**/*.rb", base: Rails.root)
    missing = mailers.reject { |path| internal_mailers.include?(path) }
                     .reject { |path| Rails.root.join(path).read.include?("@delivery_reason") }

    expect(missing).to be_empty, "set @delivery_reason in these mailers (or list them as internal here):\n#{missing.join("\n")}"
  end
end
