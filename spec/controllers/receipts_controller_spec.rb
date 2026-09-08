# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReceiptsController do
  include SessionSupport

  describe "#create" do
    let(:user) { create(:user) }
    let(:file) { fixture_file_upload("receipt.png", "image/png") }

    before { create_session(user, verified: true) }

    def upload(upload_method)
      post(:create, params: { file: [file], upload_method: }, as: :turbo_stream)
    end

    it "records the upload method sent by the receipt bin dropzone" do
      upload("receipt_center_drag_and_drop")

      expect(response).to have_http_status(:ok)
      expect(Receipt.sole.upload_method).to eq("receipt_center_drag_and_drop")
    end

    # The `file_drop` Stimulus controller appends `_drag_and_drop` client side,
    # and can append it more than once to the same field.
    it "collapses a repeated `_drag_and_drop` suffix" do
      upload("receipt_center_drag_and_drop_drag_and_drop")

      expect(response).to have_http_status(:ok)
      expect(Receipt.sole.upload_method).to eq("receipt_center_drag_and_drop")
    end

    it "still saves the receipt when the upload method is unrecognisable" do
      upload("not_a_real_upload_method")

      expect(response).to have_http_status(:ok)
      expect(Receipt.sole.upload_method).to be_nil
    end
  end

  context "models including Receiptable" do
    it "are explicitly registered" do
      Rails.application.eager_load!
      ApplicationRecord.descendants
                       .filter { _1.include?(Receiptable) }
                       .each do |klass|
        expect(ReceiptsController::RECEIPTABLE_TYPE_MAP).to have_key(klass.to_s)
      end
    end
  end
end
