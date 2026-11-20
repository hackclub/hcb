# frozen_string_literal: true

require "rails_helper"

RSpec.describe GSuite, type: :model do
  it "is valid" do
    g_suite = create(:g_suite)
    expect(g_suite).to be_valid
  end

  describe "#domain" do
    context "when domain is missing" do
      it "is not valid" do
        g_suite = build(:g_suite)

        g_suite.domain = nil
        expect(g_suite).to_not be_valid

        g_suite.domain = " "
        expect(g_suite).to_not be_valid
      end
    end

    context "when domain is missing extension" do
      it "is not valid" do
        g_suite = build(:g_suite)

        g_suite.domain = "example"

        expect(g_suite).to_not be_valid
      end
    end
  end

  describe "#verification_key" do
    it "strips out the google verification key for only the value (bit of a misnomer at this point)" do
      g_suite = build(:g_suite)

      g_suite.verification_key = "google-site-verification=Cb-_ZL"

      g_suite.save!

      expect(g_suite.reload.verification_key).to eql("Cb-_ZL")
    end
  end

  describe "#verification_url" do
    it "generates it" do
      g_suite = build(:g_suite)

      result = g_suite.verification_url

      expect(result).to eql("https://www.google.com/webmasters/verification/verification?siteUrl=http://#{g_suite.domain}&priorities=vdns,vmeta,vfile,vanalytics")
    end
  end

  describe "#aasm_state" do
    let(:g_suite) { create(:g_suite) }

    it "defaults to creating" do
      expect(g_suite).to be_creating
    end

    context "when attempting to mark configuring" do
      it "transitions" do
        expect do
          g_suite.mark_configuring!
        end.to change(g_suite, :configuring?).to(true)
      end

      context "when attempting to mark verifying" do
        before do
          g_suite.mark_configuring!
        end

        it "transitions" do
          expect do
            g_suite.mark_verifying!
          end.to change(g_suite, :verifying?).to(true)
        end

        context "when attempting to mark verified" do
          before do
            g_suite.mark_verifying!
          end

          it "transitions" do
            expect do
              g_suite.mark_verified!
            end.to change(g_suite, :verified?).to(true)
          end

          context "when attempting to go back to configuring" do
            it "fails transition" do
              expect do
                g_suite.mark_verifying!
              end.to raise_error(AASM::InvalidTransition)
            end
          end
        end
      end
    end
  end
end
