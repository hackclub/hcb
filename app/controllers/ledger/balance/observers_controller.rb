# frozen_string_literal: true

class Ledger
  module Balance
    class ObserversController < ApplicationController
      before_action :set_ledger

      def create
        @observer = @ledger.balance_observers.find_or_initialize_by(user: current_user)
        authorize @observer

        if @observer.update(amount_cents: Monetize.parse(params[:amount]).cents)
          flash[:success] = "You'll be emailed when the balance drops below #{helpers.render_money @observer.amount_cents}."
        else
          flash[:error] = @observer.errors.full_messages.to_sentence
        end

        redirect_back_or_to root_path
      end

      def destroy
        @observer = @ledger.balance_observers.find_by!(user: current_user)
        authorize @observer

        @observer.destroy!
        flash[:success] = "Balance alert removed."

        redirect_back_or_to root_path
      end

      private

      def set_ledger
        @ledger = Ledger.find_by_hashid!(params[:ledger_id])
      end

    end
  end

end
