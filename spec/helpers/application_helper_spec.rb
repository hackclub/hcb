# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#admin_process_path_for" do
    it "links an ACH transfer to its approval page" do
      ach_transfer = build_stubbed(:ach_transfer)

      expect(helper.admin_process_path_for(ach_transfer)).to eq(helper.ach_start_approval_admin_path(ach_transfer))
    end

    it "links an invoice to its process page" do
      invoice = build_stubbed(:invoice)

      expect(helper.admin_process_path_for(invoice)).to eq(helper.invoice_process_admin_path(invoice))
    end

    # HcbCode#linked_object and Ledger::Item#linked_object hand back the
    # Outgoing/Incoming wrappers rather than the Disbursement itself.
    it "links either side of a disbursement to the disbursement's process page" do
      disbursement = build_stubbed(:disbursement)
      expected = helper.disbursement_process_admin_path(disbursement)

      expect(helper.admin_process_path_for(disbursement)).to eq(expected)
      expect(helper.admin_process_path_for(disbursement.outgoing_disbursement)).to eq(expected)
      expect(helper.admin_process_path_for(disbursement.incoming_disbursement)).to eq(expected)
    end

    it "links a check deposit awaiting manual submission to its admin page" do
      check_deposit = CheckDeposit.new(id: 1, increase_status: :manual_submission_required)

      expect(helper.admin_process_path_for(check_deposit)).to eq(helper.admin_check_deposit_path(check_deposit))
    end

    # The admin page redirects straight back to the HCB code in these states.
    it "skips check deposits that don't need manual submission" do
      check_deposit = CheckDeposit.new(id: 1, increase_status: :pending)

      expect(helper.admin_process_path_for(check_deposit)).to be_nil
    end

    it "returns nil for records without a process page" do
      expect(helper.admin_process_path_for(build_stubbed(:donation))).to be_nil
      expect(helper.admin_process_path_for(nil)).to be_nil
    end
  end
end
