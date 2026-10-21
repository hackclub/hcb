# frozen_string_literal: true

require "rails_helper"

RSpec.describe Comment::ReactionsController do
  include SessionSupport

  render_views

  let(:event) { create(:event) }
  # Comments on an Event itself are admin-only, so react on something the
  # event's organizers can see.
  let(:comment) { create(:comment, commentable: create(:disbursement, event:)) }
  let(:user) { create(:user) }

  before do
    create(:organizer_position, user:, event:)
    create_session(user, verified: true)
  end

  def react(emoji: "👍")
    patch :react, params: { id: comment.id, emoji: }, format: :turbo_stream
  end

  # SQL statements issued while the block runs.
  def sql_in
    statements = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      payload = ActiveSupport::Notifications::Event.new(*args).payload
      statements << payload[:sql] unless payload[:name] == "SCHEMA"
    end
    yield
    statements
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  it "adds the reaction" do
    expect { react }.to change { comment.reactions.count }.from(0).to(1)

    expect(response).to have_http_status(:ok)
    expect(comment.reactions.sole).to have_attributes(reactor: user, emoji: "👍")
  end

  it "removes the reaction when the user reacts with the same emoji again" do
    reaction = Comment::Reaction.create!(comment:, reactor: user, emoji: "👍")

    expect { react }.to change { comment.reactions.count }.from(1).to(0)

    expect(Comment::Reaction.with_deleted.find(reaction.id)).to be_deleted
  end

  it "treats a repeated request as a toggle rather than creating a second reaction" do
    react
    react

    expect(comment.reactions.where(reactor: user, emoji: "👍")).to be_empty
    expect(Comment::Reaction.with_deleted.where(comment:, reactor: user, emoji: "👍").count).to eq(1)
  end

  it "toggles under the comment's row lock so overlapping requests cannot both create a reaction" do
    statements = sql_in { react }

    expect(statements).to include(match(/SELECT .*"comments".* FOR UPDATE/))
  end
end
