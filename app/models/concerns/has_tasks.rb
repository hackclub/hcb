# frozen_string_literal: true

module HasTasks
  extend ActiveSupport::Concern

  included do
    has_many :tasks, as: :assignee, dependent: :destroy
  end
end
