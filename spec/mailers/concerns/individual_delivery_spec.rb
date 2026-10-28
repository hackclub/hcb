# frozen_string_literal: true

require "rails_helper"

RSpec.describe IndividualDelivery, type: :mailer do
  before do
    stub_const("IndividualDeliveryTestMailer", Class.new(ApplicationMailer) do
      include IndividualDelivery

      def notify
        @greeting = params[:greeting]
        mail_individually(params[:recipients], subject: "Test subject") do |format|
          format.text { render plain: "#{@greeting} body" }
        end
      end
    end)
  end

  let(:recipients) { ["Ann <ann@example.com>", "bob@example.com"] }
  let(:delivery) { IndividualDeliveryTestMailer.with(recipients:, greeting: "Hello").notify }

  # Other specs can leave unrelated jobs in the test queue, so only look at this mailer's.
  let(:test_mailer_job) { ->(job) { job[:job] == MailDeliveryJob && job[:args].first == "IndividualDeliveryTestMailer" } }

  def test_mailer_jobs
    enqueued_jobs.select(&test_mailer_job)
  end

  it "addresses an inspected message to every recipient" do
    expect(delivery.to).to contain_exactly("ann@example.com", "bob@example.com")
    expect(delivery.subject).to eq("Test subject")
  end

  describe "#deliver_now" do
    it "delivers one message per recipient inline" do
      expect { delivery.deliver_now }.to change { ActionMailer::Base.deliveries.size }.by(2)

      expect(ActionMailer::Base.deliveries.map(&:to)).to contain_exactly(["ann@example.com"], ["bob@example.com"])
      expect(ActionMailer::Base.deliveries.map(&:subject).uniq).to eq(["Test subject"])
      expect(ActionMailer::Base.deliveries.map { |mail| mail.body.to_s }.uniq).to eq(["Hello body"])
      expect(test_mailer_jobs).to be_empty
    end

    it "delivers nothing when there are no recipients" do
      delivery = IndividualDeliveryTestMailer.with(recipients: []).notify

      expect { delivery.deliver_now }.not_to change(ActionMailer::Base.deliveries, :size)
    end

    it "dedupes recipients by address" do
      delivery = IndividualDeliveryTestMailer.with(recipients: ["Ann <ann@example.com>", "ANN@example.com", nil, "", "bob@example.com"]).notify
      delivery.deliver_now

      expect(ActionMailer::Base.deliveries.map(&:to)).to contain_exactly(["ann@example.com"], ["bob@example.com"])
    end
  end

  describe "#deliver_later" do
    it "enqueues one job, which then enqueues a job per recipient" do
      expect { delivery.deliver_later }.to have_enqueued_mail(IndividualDeliveryTestMailer, :notify).once

      expect { perform_enqueued_jobs(only: test_mailer_job) }.not_to change(ActionMailer::Base.deliveries, :size)
      expect(test_mailer_jobs.size).to eq(2)

      expect { perform_enqueued_jobs(only: test_mailer_job) }.to change(ActionMailer::Base.deliveries, :size).by(2)
      expect(ActionMailer::Base.deliveries.last(2).map(&:to)).to contain_exactly(["ann@example.com"], ["bob@example.com"])
      expect(test_mailer_jobs).to be_empty
    end
  end

  context "with earmuffed recipients" do
    before do
      allow(ApplicationMailer).to receive(:earmuffed_recipients).and_return(["bob@example.com"])
    end

    it "leaves earmuffed users out of group emails" do
      delivery.deliver_now

      expect(ActionMailer::Base.deliveries.map(&:to)).to eq([["ann@example.com"]])
    end

    it "still delivers when every recipient is earmuffed" do
      IndividualDeliveryTestMailer.with(recipients: ["bob@example.com"]).notify.deliver_now

      expect(ActionMailer::Base.deliveries.map(&:to)).to eq([["bob@example.com"]])
    end
  end

  it "requires the mailer to be called with params" do
    expect { IndividualDeliveryTestMailer.notify.deliver_now }.to raise_error(ArgumentError, /with\(/)
  end

  it "rejects a to: header" do
    stub_const("ToHeaderTestMailer", Class.new(ApplicationMailer) do
      include IndividualDelivery

      def notify
        mail_individually([], to: "ann@example.com", subject: "Test subject")
      end
    end)

    expect { ToHeaderTestMailer.with({}).notify.deliver_now }.to raise_error(ArgumentError, /to:/)
  end
end
