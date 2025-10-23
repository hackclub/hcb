# frozen_string_literal: true

# == Schema Information
#
# Table name: tasks
#
#  id            :bigint           not null, primary key
#  assignee_type :string           not null
#  complete      :boolean          default(FALSE)
#  completed_at  :datetime
#  taskable_type :string           not null
#  type          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  assignee_id   :bigint           not null
#  taskable_id   :bigint           not null
#
# Indexes
#
#  index_tasks_on_assignee  (assignee_type,assignee_id)
#  index_tasks_on_taskable  (taskable_type,taskable_id)
#

class Task < ApplicationRecord
  belongs_to :taskable, polymorphic: true
  belongs_to :assignee, polymorphic: true
  validates_presence_of :taskable, :assignee
  broadcasts_refreshes_to ->(task) { [task.assignee, :tasks] }

  scope :complete, -> { where(complete: true) }
  scope :incomplete, -> { where(complete: false) }

  after_initialize do
    raise "Cannot directly instantiate a Task" if self.instance_of? Task
  end

  before_save do
    completed_at = complete ? Time.now : nil if complete_changed?
  end

  def update_complete!
    nil
  end

  def url
    Rails.application.routes.url_helpers.url_for(taskable)
  end

  def text
    "Unknown task"
  end

end
