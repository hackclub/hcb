# frozen_string_literal: true

module Payroll
  class Position
    class ExpireJob < ApplicationJob
      queue_as :low
      discard_on ActiveJob::DeserializationError

      def perform(position)
        position.mark_expired! if position.onboarded?
      end

    end

  end

end
