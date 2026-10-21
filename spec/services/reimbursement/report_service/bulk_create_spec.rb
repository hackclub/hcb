# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reimbursement::ReportService::BulkCreate do
  let!(:event) { create(:event) }
  let!(:sent_by) { create(:user) }

  def upload(content, reviewer_id: nil)
    described_class.new(event:, sent_by:, csv_file: StringIO.new(content), reviewer_id:).run
  end

  it "creates draft reports for existing and new contributors and queues their invitations" do
    existing_user = create(:user, email: "alice@example.com")
    payout_method = create(:legal_entity_payout_method, legal_entity: existing_user.personal_legal_entity,
                                                         details: create(:wise_transfer_payout_method_details), default: true)
    result = nil

    expect {
      result = upload(<<~CSV)
        email,report_name,maximum_amount_cents,invite_message
         ALICE@example.com , Train tickets ,, Thanks Alice!
        bob@example.com,Club supplies,12500,
      CSV
    }.to have_enqueued_mail(ReimbursementMailer, :invitation).exactly(2).times

    expect(result.success?).to be true
    expect(result.errors).to be_empty
    expect(event.reimbursement_reports).to match_array(result.reports)
    alice, bob = result.reports.map(&:reload)
    expect(alice).to have_attributes(user: existing_user, event:, inviter: sent_by, name: "Train tickets",
                                     currency: "GBP", payout_method:, maximum_amount_cents: nil, invite_message: "Thanks Alice!", aasm_state: "draft")
    expect(bob).to have_attributes(event:, inviter: sent_by, name: "Club supplies", currency: "USD",
                                   maximum_amount_cents: 12500, invite_message: nil, aasm_state: "draft")
    expect(bob.user).to have_attributes(email: "bob@example.com", creation_method: "reimbursement_report")
  end

  it "accepts Excel BOMs and headers with different casing or surrounding whitespace" do
    result = upload("\uFEFF EMAIL , Report_Name \r\nalice@example.com,Travel\r\n")

    expect(result.success?).to be true
    expect(result.reports.sole).to have_attributes(name: "Travel")
    expect(result.reports.sole.user.email).to eq("alice@example.com")
  end

  it "reports invalid rows without creating users, reports, or invitations" do
    result = nil

    expect {
      result = upload("email,report_name,maximum_amount_cents\nalice@example.com,Valid,100\ninvalid,,1.5\n")
    }.not_to(change { [User.count, Reimbursement::Report.count, enqueued_jobs.size] })

    expect(result.success?).to be false
    expect(result.reports).to be_empty
    expect(result.errors).to include("Row 3: 'invalid' is not a valid email address", "Row 3: report_name is required")
    expect(result.errors.join).to include("Row 3: maximum_amount_cents")
  end

  it "rolls back earlier rows when a later contributor fails user validation" do
    result = nil

    expect {
      result = upload("email,report_name\nalice@example.com,Travel\ncontributor@tormails.com,Supplies\n")
    }.not_to(change { [User.count, Reimbursement::Report.count, enqueued_jobs.size] })

    expect(result.success?).to be false
    expect(result.reports).to be_empty
    expect(result.errors.sole).to start_with("Row 3: Email")
  end

  it "rejects zero, negative, fractional, nonnumeric, and overflowing maximum amounts" do
    ["0", "-100", "1.5", "USD 100", "2147483648"].each do |amount|
      result = upload("email,report_name,maximum_amount_cents\nalice@example.com,Travel,#{amount}\n")

      expect(result.success?).to be false
      expect(result.errors.join).to include("Row 2: maximum_amount_cents")
    end
    expect(event.reimbursement_reports.count).to eq(0)
  end

  it "returns helpful errors for missing columns, empty data, and malformed files" do
    {
      "email\nalice@example.com\n"     => "Missing required headers: report_name",
      "email,report_name\n"            => "CSV file has no data rows",
      ""                               => "CSV file is empty or has no headers",
      "email,report_name\n\"unclosed"  => "Invalid CSV format:",
      "email,report_name\n\xFF,Travel" => "valid UTF-8",
      "a" * (1.megabyte + 1)           => "File is too large"
    }.each do |csv, message|
      result = upload(csv)

      expect(result.success?).to be false
      expect(result.errors.join).to include(message)
    end
  end

  context "when the plan requires an assigned reviewer" do
    let(:event) { create(:event, plan_type: Event::Plan::HackClubHQ) }

    it "assigns an eligible reviewer to every report" do
      reviewer = create(:user)
      create(:organizer_position, :manager, event:, user: reviewer)

      result = upload("email,report_name\nalice@example.com,Travel\nbob@example.com,Supplies\n", reviewer_id: reviewer.public_id)

      expect(result.success?).to be true
      expect(result.reports.map(&:reviewer)).to eq([reviewer, reviewer])
    end

    it "rejects missing reviewers and reviewers outside the organization without creating records" do
      outsider = create(:user)

      [nil, outsider.public_id].each do |reviewer_id|
        result = nil
        expect {
          result = upload("email,report_name\nalice@example.com,Travel\n", reviewer_id:)
        }.not_to(change { [User.count, Reimbursement::Report.count, enqueued_jobs.size] })

        expect(result.success?).to be false
        expect(result.errors).to include("Please select an eligible reviewer for these reports")
      end
    end
  end
end
