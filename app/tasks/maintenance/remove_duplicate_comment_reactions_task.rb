# frozen_string_literal: true

module Maintenance
  # One-time cleanup for hackclub/hcb#15016. The reaction picker submitted
  # every click twice, and both requests could get through the find-then-create
  # in `Comment::ReactionsController#react` (fixed in #15385), leaving the same
  # user with two or more live reactions for one emoji on one comment.
  #
  # Keeps the oldest live reaction in each (comment, reactor, emoji) group and
  # soft-deletes the rest. Run once after #15385 is deployed, and before the
  # unique index on `comment_reactions` is added.
  class RemoveDuplicateCommentReactionsTask < MaintenanceTasks::Task
    def collection
      oldest_per_group = Comment::Reaction.group(:comment_id, :reactor_id, :emoji).select("MIN(id)")

      Comment::Reaction.where.not(id: oldest_per_group)
    end

    def process(reaction)
      reaction.destroy!
    end

  end
end
