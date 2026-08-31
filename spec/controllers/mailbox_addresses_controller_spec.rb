# frozen_string_literal: true

require "rails_helper"

RSpec.describe MailboxAddressesController do
  include SessionSupport
  render_views

  describe "#activate" do
    it "activates the address and flashes a success message over turbo_stream" do
      user = create(:user)
      mailbox_address = user.mailbox_addresses.create!
      create_session(user, verified: true)

      post(:activate, params: { id: mailbox_address.id }, as: :turbo_stream)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq(Mime[:turbo_stream])
      expect(flash.now[:success]).to eq("Address activated!")
      expect(response.body).to include("Address activated!")
      # The address row is updated in place rather than triggering a full reload.
      expect(response.body).to include('target="mailbox_address"')

      expect(mailbox_address.reload).to be_activated
    end

    it "activates the address and redirects with a flash for a plain html request" do
      user = create(:user)
      mailbox_address = user.mailbox_addresses.create!
      create_session(user, verified: true)

      post(:activate, params: { id: mailbox_address.id }, as: :html)

      expect(response).to redirect_to(mailbox_address)
      expect(flash[:success]).to eq("Address activated!")
      expect(mailbox_address.reload).to be_activated
    end
  end
end
