# frozen_string_literal: true

require "rails_helper"

# Database-level counterpart of the model's uniqueness validation.
RSpec.describe Comment::Reaction, type: :model do
  let(:event) { create(:event) }
  let(:comment) { create(:comment, commentable: event) }
  let(:reactor) { create(:user) }

  # Skips validations, so only the database stands in the way.
  def insert_reaction(by: reactor, emoji: "👍")
    described_class.new(comment:, reactor: by, emoji:).tap { |reaction| reaction.save!(validate: false) }
  end

  describe "unique index on live reactions" do
    it "rejects a second live reaction with the same comment, reactor and emoji" do
      insert_reaction

      expect { insert_reaction }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows a new live reaction once the previous one was soft-deleted" do
      insert_reaction.destroy!

      expect { insert_reaction }.not_to raise_error
    end

    it "allows the same emoji from another reactor" do
      insert_reaction

      expect { insert_reaction(by: create(:user)) }.not_to raise_error
    end
  end
end
