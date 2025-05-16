# frozen_string_literal: true

class DeleteStalePlaygroundEvents < ApplicationJob
  queue_as :low

  def perform
    Event.demo_mode.where("created_at < ?", 6.months.ago).delete_all
  end

end
