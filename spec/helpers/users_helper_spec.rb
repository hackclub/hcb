# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsersHelper, type: :helper do
  describe "#user_mention" do
    let(:auditor) { create(:user, :make_auditor) }
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

    # Mentions are rendered inside links (a document card, a card charge's spender), and
    # HTML doesn't nest links: without the <template>, the browser closes the outer link at
    # the menu's first link and the menu's items land on the page, outside the menu.
    it "keeps the admin tools menu intact when the mention is inside a link" do
      allow(helper).to receive(:current_user).and_return(create(:user, :make_admin))
      allow(helper).to receive(:current_session).and_return(nil)

      page = Nokogiri::HTML5.fragment(%(<a id="outer" href="/stripe_cards/1">#{helper.user_mention(mentioned_user)}</a>))
      outer = page.at_css("#outer")
      menu = outer.at_css("template[data-menu-target='content']")

      expect(menu).to be_present
      items = page.css(".menu__content > .menu__item")
      expect(items.map { |item| item.ancestors("template").first }).to all(eq(menu)) # none spilled out

      expect(items.map { |item| item.text.strip }).to eq(["Email", "Copy email", "Impersonate", "Settings"])
      expect(items.first["href"]).to eq("mailto:#{mentioned_user.email}")
    end

    describe "impersonate menu item" do
      let(:admin) { create(:user, :make_admin) }
      let(:session) { nil }

      before do
        allow(helper).to receive(:current_user).and_return(admin)
        allow(helper).to receive(:current_session).and_return(session)
      end

      it "is shown to an admin viewing another user" do
        html = helper.user_mention(mentioned_user)

        expect(html).to include("Impersonate")
        expect(html).to include(helper.impersonate_user_path(mentioned_user.id))
      end

      # Markdown comments render mentions outside a request
      it "renders without a request" do
        allow(helper).to receive(:request).and_return(nil)

        expect(helper.user_mention(mentioned_user)).to include("Impersonate")
      end

      it "is hidden from auditors, who can't impersonate" do
        allow(helper).to receive(:current_user).and_return(create(:user, :make_auditor))

        expect(helper.user_mention(mentioned_user)).not_to include("Impersonate")
      end

      it "is hidden on the admin's own mention" do
        expect(helper.user_mention(admin)).not_to include("Impersonate")
      end

      context "when already impersonating" do
        let(:session) { build_stubbed(:user_session, user: admin, impersonated_by: create(:user, :make_admin)) }

        it "is hidden to prevent nested impersonation" do
          expect(helper.user_mention(mentioned_user)).not_to include("Impersonate")
        end
      end
    end
  end
end
