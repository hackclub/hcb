# frozen_string_literal: true

require "rails_helper"

RSpec.describe OneTimeJobs::NotifyUsersWithIncompletePayoutMethods do
  def wise_default_for(user, birthday:)
    user.personal_legal_entity.payout_methods.create!(default: true, details: create(:wise_transfer_payout_method_details)).tap do |pm|
      pm.details.update!(recipient_birthday: birthday)
    end
  end

  it "emails only users whose default Wise method is missing required details" do
    incomplete_user = create(:user)
    complete_user = create(:user)
    incomplete = wise_default_for(incomplete_user, birthday: nil)
    wise_default_for(complete_user, birthday: "01/15/1990")

    expect { described_class.perform_now }
      .to have_enqueued_mail(UserMailer, :incomplete_payout_method).with(user: incomplete_user, payout_method: incomplete).once
  end
end
