# frozen_string_literal: true

require "rails_helper"

RSpec.describe Column::AccountNumberPolicy, type: :policy do
  describe "#create?" do
    let(:event) { create(:event) }
    let(:user) { create(:user) }

    subject { described_class.new(user, event.build_column_account_number).create? }

    context "as a manager" do
      before { create(:organizer_position, user:, event:, role: :manager) }

      it "is allowed" do
        is_expected.to eq(true)
      end

      context "when the organization is in Playground Mode" do
        let(:event) { create(:event, :demo_mode) }

        it "is denied" do
          is_expected.to eq(false)
        end
      end
    end

    context "as an auditor" do
      let(:user) { create(:user, :make_auditor) }

      context "when the organization is in Playground Mode" do
        let(:event) { create(:event, :demo_mode) }

        it "is denied" do
          is_expected.to eq(false)
        end
      end
    end
  end
end
