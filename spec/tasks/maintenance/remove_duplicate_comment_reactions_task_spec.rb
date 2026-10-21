# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::RemoveDuplicateCommentReactionsTask do
  let(:event) { create(:event) }
  let(:comment) { create(:comment, commentable: event) }
  let(:user) { create(:user) }

  # The model validation rejects duplicates, so insert them the way the race
  # did: straight into the table.
  def insert_reaction(on: comment, reactor: user, emoji: "👍")
    Comment::Reaction.new(comment: on, reactor:, emoji:).tap { |reaction| reaction.save!(validate: false) }
  end

  def run_task
    task = described_class.new
    task.collection.find_each { |reaction| task.process(reaction) }
  end

  it "keeps the oldest live reaction in each group and soft-deletes the rest" do
    original = insert_reaction
    duplicates = [insert_reaction, insert_reaction]

    run_task

    expect(original.reload).not_to be_deleted
    expect(duplicates.map { |duplicate| Comment::Reaction.with_deleted.find(duplicate.id) }).to all(be_deleted)
  end

  it "leaves reactions that differ by emoji, reactor or comment alone" do
    insert_reaction
    insert_reaction(emoji: "🎉")
    insert_reaction(reactor: create(:user))
    insert_reaction(on: create(:comment, commentable: event))

    expect { run_task }.not_to(change { Comment::Reaction.count })
  end

  it "does not treat an already-removed reaction as a duplicate of a live one" do
    insert_reaction.destroy!
    live = insert_reaction

    expect { run_task }.not_to(change { Comment::Reaction.count })
    expect(live.reload).not_to be_deleted
  end
end
