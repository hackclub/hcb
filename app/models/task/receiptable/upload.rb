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
class Task
  module Receiptable
    class Upload < Task
      scope :for_hcb_code, -> { where(taskable_type: "HcbCode") }

      def update_complete!
        update(complete: taskable.nil? || !taskable.missing_receipt? || !taskable.receipt_required?)
      end

      def text
        "Upload receipt for #{taskable.try(:memo) || "transaction"}"
      end

    end
  end

end
