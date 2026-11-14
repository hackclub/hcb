# frozen_string_literal: true

require "rails_helper"

RSpec.describe FieldGuard do
  # AchTransferPolicy: `fields :account_number, :routing_number, if: :view_account_routing_numbers?`,
  # which allows admins and managers.
  let(:event) { create(:event, :with_positive_balance) }
  # Created up front: saving reads these fields too, and rendering never saves.
  let!(:ach_transfer) { create(:ach_transfer, event:, account_number: "123456789") }
  let(:manager) { organizer(:manager) }
  let(:member) { organizer(:member) }

  def organizer(role)
    create(:user).tap { |user| create(:organizer_position, user:, event:, role:) }
  end

  it "reads fields normally outside rendering" do
    expect(ach_transfer.account_number).to eq("123456789")
    expect(ach_transfer.readable?(:account_number)).to be(true)
  end

  describe "while rendering" do
    it "returns the value to a viewer the policy allows" do
      described_class.enforce(manager) do
        expect(ach_transfer.readable?(:account_number)).to be(true)
        expect(ach_transfer.account_number).to eq("123456789")
      end
    end

    it "raises when a viewer the policy doesn't allow reads the field" do
      described_class.enforce(member) do
        expect(ach_transfer.readable?(:account_number)).to be(false)
        expect { ach_transfer.account_number }.to raise_error(FieldGuard::Violation, /AchTransfer#account_number/)
      end
    end

    it "leaves fields without a rule alone" do
      described_class.enforce(member) do
        expect(ach_transfer.bank_name).to eq(ach_transfer[:bank_name])
      end
    end

    it "doesn't guard unsaved records, whose values came from the viewer" do
      described_class.enforce(member) do
        expect(AchTransfer.new(account_number: "42").account_number).to eq("42")
      end
    end

    it "lets policies read real values" do
      described_class.enforce(member) do
        expect(described_class.unguarded { ach_transfer.account_number }).to eq("123456789")
      end
    end

    it "is off again once rendering finishes" do
      described_class.enforce(member) { nil }

      expect(ach_transfer.account_number).to eq("123456789")
    end

    describe ".omit_hidden" do
      it "returns nil when the block reads a field the viewer can't see" do
        described_class.enforce(member) do
          expect(described_class.omit_hidden { ach_transfer.account_number }).to be_nil
        end
      end

      it "returns the block's value otherwise" do
        described_class.enforce(manager) do
          expect(described_class.omit_hidden { ach_transfer.account_number }).to eq("123456789")
        end
      end
    end

    context "when violations are reported instead of raised, as in production" do
      around do |example|
        Rails.configuration.x.field_guard.on_violation = :report
        example.run
      ensure
        Rails.configuration.x.field_guard.on_violation = nil
      end

      it "reports the read and returns a placeholder" do
        expect(Rails.error).to receive(:report).with(instance_of(FieldGuard::Violation), handled: true)

        described_class.enforce(member) do
          expect(ach_transfer.account_number).to be(FieldGuard::HIDDEN)
        end
      end
    end
  end
end
