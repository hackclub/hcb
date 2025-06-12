# frozen_string_literal: true

class Task
  class NightlyJob < ApplicationJob
    queue_as :low
    def perform
      ::TaskService::Nightly.new.run
    end

  end

end
