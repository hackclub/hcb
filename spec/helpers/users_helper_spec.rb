# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsersHelper, type: :helper do
  describe "#user_mention" do
    let(:auditor) { create(:user, :make_admin) }
    let(:mentioned_user) { create(:user) }

    before { allow(helper).to receive(:current_user).and_return(auditor) }

    # The admin tools menu (Email / Copy email / Settings) is intended for mentions
    # displayed inside posted comments, where an auditor clicks a teammate to act on them.
    it "renders the admin tools menu for an auditor viewing a mention" do
      html = helper.user_mention(mentioned_user)

      expect(html).to include('data-controller="menu"')
      expect(html).to include("Copy email")
    end

    # The same helper renders each option in the "@" mention autocomplete dropdown. There,
    # clicking an avatar must select the mention, not pop open the admin tools menu.
    it "omits the admin tools menu when disable_admin_menu is set" do
      html = helper.user_mention(mentioned_user, disable_admin_menu: true)

      expect(html).not_to include('data-controller="menu"')
      expect(html).not_to include("Copy email")
    end
  end
end
