# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationMailer, type: :mailer do
  describe "#prevent_noisy_delivery" do
    # Create a test mailer class to test the prevent_noisy_delivery callback
    let(:test_mailer_class) do
      Class.new(ApplicationMailer) do
        def test_email(recipients:)
          mail(to: recipients, subject: "Test Subject") do |format|
            format.text { render plain: "Test body" }
            format.html { render html: "<p>Test body</p>".html_safe }
          end
        end
      end
    end
    let(:normal_recipient) { "normal@example.com" }
    let(:another_normal_recipient) { "another@example.com" }
    let(:earmuffed_recipient) { "earmuffed@example.com" }
    let(:another_earmuffed_recipient) { "another_earmuffed@example.com" }

    before do
      allow(ApplicationMailer).to receive(:earmuffed_recipients).and_return([earmuffed_recipient, another_earmuffed_recipient])
    end

    context "when there are no earmuffed recipients" do
      it "delivers to all recipients" do
        mail = test_mailer_class.test_email(recipients: [normal_recipient, another_normal_recipient])
        expect(mail.to).to contain_exactly(normal_recipient, another_normal_recipient)
      end
    end

    context "when there are earmuffed recipients among other recipients" do
      it "filters out earmuffed recipients" do
        mail = test_mailer_class.test_email(recipients: [normal_recipient, earmuffed_recipient, another_normal_recipient])
        expect(mail.to).to contain_exactly(normal_recipient, another_normal_recipient)
        expect(mail.to).not_to include(earmuffed_recipient)
      end
    end

    context "when all recipients are earmuffed" do
      it "sends the email normally without filtering" do
        mail = test_mailer_class.test_email(recipients: [earmuffed_recipient, another_earmuffed_recipient])
        expect(mail.to).to contain_exactly(earmuffed_recipient, another_earmuffed_recipient)
      end
    end

    context "when the only recipient is earmuffed" do
      it "sends the email normally without filtering" do
        mail = test_mailer_class.test_email(recipients: [earmuffed_recipient])
        expect(mail.to).to contain_exactly(earmuffed_recipient)
      end
    end

    context "when recipients list is empty" do
      it "keeps the recipients list empty" do
        mail = test_mailer_class.test_email(recipients: [])
        expect(mail.to).to be_empty
      end
    end

    context "with multiple earmuffed recipients and one normal recipient" do
      it "only keeps the normal recipient" do
        mail = test_mailer_class.test_email(recipients: [normal_recipient, earmuffed_recipient, another_earmuffed_recipient])
        expect(mail.to).to contain_exactly(normal_recipient)
        expect(mail.to).not_to include(earmuffed_recipient)
        expect(mail.to).not_to include(another_earmuffed_recipient)
      end
    end

    context "when recipients are in 'Name <email>' format" do
      it "filters out earmuffed recipients by email address" do
        earmuffed_with_name = "Earmuffed User <#{earmuffed_recipient}>"
        normal_with_name = "Normal User <#{normal_recipient}>"

        mail = test_mailer_class.test_email(recipients: [normal_with_name, earmuffed_with_name])
        expect(mail.to).to contain_exactly(normal_recipient)
        expect(mail.to).not_to include(earmuffed_recipient)
      end

      it "sends normally when only earmuffed recipient with name format" do
        earmuffed_with_name = "Earmuffed User <#{earmuffed_recipient}>"

        mail = test_mailer_class.test_email(recipients: [earmuffed_with_name])
        expect(mail.to).to contain_exactly(earmuffed_recipient)
      end

      it "handles mixed formats (with and without names)" do
        earmuffed_with_name = "Earmuffed User <#{earmuffed_recipient}>"
        normal_with_name = "Normal User <#{normal_recipient}>"

        mail = test_mailer_class.test_email(recipients: [normal_with_name, another_earmuffed_recipient, earmuffed_with_name, another_normal_recipient])
        expect(mail.to).to contain_exactly(normal_recipient, another_normal_recipient)
        expect(mail.to).not_to include(earmuffed_recipient)
        expect(mail.to).not_to include(another_earmuffed_recipient)
      end
    end
  end
end
