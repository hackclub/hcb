# frozen_string_literal: true

require "rails_helper"

RSpec.describe AiSafetyInquiryMailer do
  let(:inquiry) { { name: "Ada Park", email: "ada@example.org", audience: "team", message: "Three researchers.", ref: "newsletter" } }

  describe "#confirmation" do
    it "goes to the submitter with replies to the team inbox and does not echo untrusted message text" do
      mail = described_class.with(**inquiry).confirmation

      expect(mail.to).to eq(["ada@example.org"])
      expect(mail.reply_to).to eq(["aisafety@hackclub.com"])
      expect(mail.cc).to be_blank
      expect(mail.bcc).to be_blank
      expect(mail.subject).to eq("Thanks for reaching out to HCB")
      expect(mail.body.encoded).to include("Hi Ada,")
      expect(mail.body.encoded).not_to include("Three researchers.")
    end

    # Uses the no-footer layout: the default footer has a phone number and student-focused copy.
    it "has no default footer copy and no em dashes" do
      body = described_class.with(**inquiry).confirmation.body.encoded

      expect(body).not_to include("By the students")
      expect(body).not_to match(/\(\d{3}\)|\d{3}[\s.-]\d{3}[\s.-]\d{4}/)
      expect(body).not_to include("\u2014")
    end

    # The form mails an address the visitor typed, so it must not carry a spammer's link.
    it "leaves out a link-ish name and never echoes message URLs" do
      body = described_class.with(**inquiry, name: "Bob evil.com", message: "see bit.ly/x").confirmation.body.encoded

      expect(body).to include("Hi,")
      expect(body).not_to include("Bob")
      expect(body).not_to include("bit.ly")
    end
  end

  describe "#notify_team" do
    it "goes to the team inbox with replies to the submitter" do
      mail = described_class.with(**inquiry).notify_team

      expect(mail.to).to eq(["aisafety@hackclub.com"])
      expect(mail.reply_to).to eq(["ada@example.org"])
      expect(mail.subject).to eq("AI safety inquiry: A funded team or researcher from Ada Park")
      expect(mail.body.encoded).to include("ada@example.org", "Three researchers.", "newsletter", "/for/ai-safety")
    end

    it "keeps a CRLF in the name out of the headers" do
      mail = described_class.with(**inquiry, name: "Ada\r\nBcc: victim@example.com").notify_team

      expect(mail.reply_to).to eq(["ada@example.org"])
      expect(mail.bcc).to be_blank
      expect(mail.subject).not_to include("\n")
      expect(mail.subject).to eq("AI safety inquiry: A funded team or researcher from Ada Bcc: victim@example.com")
    end
  end
end
