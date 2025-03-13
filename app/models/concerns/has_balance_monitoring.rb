# frozen_string_literal: true

module HasBalanceMonitoring
  extend ActiveSupport::Concern

  included do
    after_save do
      Airbrake.notify("#{event.name} has a negative balance: #{ApplicationController.helpers.render_money event.balance}") if event.balance.negative?
    end
  end
end
