# frozen_string_literal: true

module Users
  class WrappedController < ApplicationController
    include UsersHelper
    skip_after_action :verify_authorized
    before_action :set_data

    def index
      unless Flipper.enabled?(:bank_wrapped, current_user)
        render plain: "HCB Wrapped coming soon! I heard #{current_user&.first_name.presence&.concat("'s") || "you're"} on the naughty list 🎅" and return
      end

      ahoy.track "Wrapped 2024 viewed", user_id: current_user.id if current_user == @user

      render layout: "bare"
    end

    def data
      headers["Content-Disposition"] = "attachment; filename=wrapped.json"

      render json: @data
    end

    private

    def set_data
      if current_user.auditor? && params[:user_email].present?
        @user = User.find_by(email: params[:user_email])
      end
      @user ||= current_user

      @data = {
        individual: {
          name: @user.full_name,
          firstName: @user.first_name,
          id: @user.id,
          profilePicture: profile_picture_for(@user, 256),
          totalMoneySpent: Metric::User::TotalSpent.from(@user).metric,
          spendingByDate: Metric::User::SpendingByDate.from(@user).metric,
          ranking: Metric::Hcb::SpendingByUser.metric.keys.index(@user.id).to_f / Metric::Hcb::SpendingByUser.metric.keys.size, # this still needs to be done, we have spending by user
          averageReceiptUploadTime: Metric::User::TimeToReceipt.from(@user).metric, # in seconds
          lostReceiptCount: Metric::User::LostReceiptCount.from(@user).metric,
          platinumCard: Metric::User::PlatinumCard.from(@user).metric,
          words: Metric::User::Words.from(@user).metric.first(20).to_h.keys, # needs a format change to an array (rn it's a has)
          spendingByLocation: Metric::User::SpendingByLocation.from(@user).metric, # needs a format change on the React-side, should match spendingByCat format
          spendingByCategory: Metric::User::SpendingByCategory.from(@user).metric,
          spendingByMerchant: Metric::User::SpendingByMerchant.from(@user).metric,
          cardGrantCount: Metric::User::CardGrantCount.from(@user).metric,
          cardGrantAmount: Metric::User::CardGrantAmount.from(@user).metric,
          reimbursementCount: Metric::User::ReimbursementCount.from(@user).metric,
          reimbursementAmount: Metric::User::ReimbursementAmount.from(@user).metric,
          bestFriend: Metric::User::MostInteractedWith.from(@user).metric
        },
        organizations: @user.events.to_h do |event|
          [
            event.name,
            {
              spendingByUser: Metric::Event::SpendingByUser.from(event).metric,
              category: nil,
              spent: Metric::Event::TotalSpent.from(event).metric,
              raised: Metric::Event::TotalRaised.from(event).metric,
              spendingByDate: Metric::Event::SpendingByDate.from(event).metric,
              spendingByLocation: Metric::Event::SpendingByLocation.from(event).metric,
              spendingByCategory: Metric::Event::SpendingByCategory.from(event).metric,
              spendingByMerchant: Metric::Event::SpendingByMerchant.from(event).metric,
              logo_url: event.logo.attached? ? Rails.application.routes.url_helpers.url_for(event.logo) : nil
            }
          ]
        end,
        hcb: {
          raised: Metric::Hcb::TotalRaised.metric,
          spent: Metric::Hcb::TotalSpent.metric,
          organizations: {
            total: Metric::Hcb::TotalEvents.metric,
            new: Metric::Hcb::NewEvents.metric,
          },
          users: {
            total: Metric::Hcb::TotalUsers.metric,
            new: Metric::Hcb::NewUsers.metric,
          },
          spendingByLocation: Metric::Hcb::SpendingByLocation.metric,
          spendingByCategory: Metric::Hcb::SpendingByCategory.metric,
          spendingByMerchant: Metric::Hcb::SpendingByMerchant.metric,
          merchantCount: Metric::Hcb::MerchantCount.metric,
          spendingByDate: Metric::Hcb::SpendingByDate.metric,
        },
      }
    end

  end
end
