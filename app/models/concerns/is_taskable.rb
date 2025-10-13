# frozen_string_literal: true

module IsTaskable
  extend ActiveSupport::Concern

  included do
    has_many :tasks, as: :taskable, dependent: :destroy

    def update_task_completion
      tasks.each(&:update_complete!)
    end

    after_commit :update_task_completion
  end
end
