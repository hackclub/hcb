# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#sorted_relation" do
    let(:relation) { instance_double(ActiveRecord::Relation) }

    before do
      allow(helper).to receive(:organizer_signed_in?).and_return(true)
    end

    it "uses a custom order handler for computed sort columns" do
      ordered_relation = instance_double(ActiveRecord::Relation)
      columns = [{
        key: "amount",
        order: ->(current_relation, direction) do
          expect(current_relation).to eq(relation)
          expect(direction).to eq(:asc)

          ordered_relation
        end
      }]

      expect(helper.sorted_relation(relation, columns, sort: %w[amount asc], default: [:amount, :desc])).to eq(ordered_relation)
    end

    it "falls back to the default direction before calling a custom order handler" do
      columns = [{
        key: "amount",
        order: ->(current_relation, direction) do
          expect(current_relation).to eq(relation)
          expect(direction).to eq(:desc)

          relation
        end
      }]

      helper.sorted_relation(relation, columns, sort: ["amount", "sideways"], default: [:amount, :desc])
    end
  end
end
