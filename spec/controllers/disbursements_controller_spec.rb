# frozen_string_literal: true

require "rails_helper"

RSpec.describe DisbursementsController do
  include SessionSupport

  describe "#event_search" do
    def search(params = {})
      get :event_search, params: { q: "YSWS" }.merge(params), format: :json
    end

    def options
      JSON.parse(response.body)
    end

    def labels
      options.map { |option| option["label"] }
    end

    def admin_label(event)
      "#{event.name} (#{event.id})"
    end

    def sign_in_admin
      create(:user, access_level: :admin).tap { |user| create_session(user, verified: true) }
    end

    context "when ranking matches" do
      before { @admin = sign_in_admin }

      # The endpoint returns at most 25 rows and orders the caller's own
      # organizations first, so an org whose name is a prefix of many others
      # ("YSWS" vs "YSWS - ...") used to fall off the end of that window.
      it "returns the exact match even when swamped by the caller's own partial matches" do
        30.times { |i| create(:organizer_position, user: @admin, event: create(:event, name: "YSWS - Project #{i}")) }
        exact = create(:event, name: "YSWS")

        search

        expect(labels.first).to eq(admin_label(exact))
      end

      it "ranks exact, then prefix, then substring matches" do
        substring = create(:event, name: "Big YSWS Thing")
        prefix = create(:event, name: "YSWS - Project")
        exact = create(:event, name: "YSWS")

        search

        expect(labels).to eq([exact, prefix, substring].map { |event| admin_label(event) })
      end

      it "matches case-insensitively in both directions" do
        create(:event, name: "Some ysws project")
        exact = create(:event, name: "ysws")

        search(q: "YSWS")

        expect(labels.first).to eq(admin_label(exact))
      end

      it "ranks an exact slug match above a mere prefix match on a name" do
        prefixed = create(:event, name: "ysws-hq extras")
        create(:organizer_position, user: @admin, event: prefixed)
        renamed = create(:event, name: "Renamed Org", slug: "ysws-hq")

        search(q: "ysws-hq")

        expect(labels).to eq([renamed, prefixed].map { |event| admin_label(event) })
      end

      # A NULL slug makes the comparison NULL, and Postgres sorts NULLs first
      # under DESC, so an unrelated org could otherwise outrank the real match.
      it "does not float orgs with a NULL slug to the top" do
        slugless = create(:event, name: "Some YSWS thing")
        slugless.update_column(:slug, nil)
        exact = create(:event, name: "YSWS")

        search

        expect(labels).to eq([exact, slugless].map { |event| admin_label(event) })
      end

      it "keeps the caller's own orgs first within a rank" do
        create(:event, name: "YSWS - Alpha")
        mine = create(:event, name: "YSWS - Zulu")
        create(:organizer_position, user: @admin, event: mine)
        exact = create(:event, name: "YSWS")

        search

        expect(labels).to eq([exact, mine].map { |event| admin_label(event) } + ["YSWS - Alpha (#{Event.find_by(name: 'YSWS - Alpha').id})"])
      end

      it "breaks ties between identically named orgs deterministically" do
        first = create(:event, name: "YSWS")
        second = create(:event, name: "YSWS")

        search

        expect(labels).to eq([first, second].sort_by(&:id).map { |event| admin_label(event) })
      end
    end

    context "when the query contains special characters" do
      before { @admin = sign_in_admin }

      it "treats a percent sign as literal text rather than a wildcard" do
        create(:event, name: "Alpha")
        create(:event, name: "Beta")
        literal = create(:event, name: "Save 100% Now")

        search(q: "%")

        expect(labels).to eq([admin_label(literal)])
      end

      it "does not let an underscore wildcard match arbitrary characters" do
        create(:event, name: "AXB Club")
        exact = create(:event, name: "A_B")

        search(q: "A_B")

        expect(labels).to eq([admin_label(exact)])
      end

      # An unescaped "_" in the prefix pattern would match any character, so a
      # non-prefix org would tie for the top rank and win on caller preference.
      it "treats wildcards as literal when ranking prefix matches" do
        decoy = create(:event, name: "AXB, which also contains A_B")
        create(:organizer_position, user: @admin, event: decoy)
        literal_prefix = create(:event, name: "A_B Club")

        search(q: "A_B")

        expect(labels).to eq([literal_prefix, decoy].map { |event| admin_label(event) })
      end

      it "handles quotes without raising" do
        exact = create(:event, name: "O'Brien's Org")

        search(q: "O'Brien's Org")

        expect(response).to have_http_status(:ok)
        expect(labels).to include(admin_label(exact))
      end
    end

    context "without a query" do
      before { @admin = sign_in_admin }

      it "returns results and caps them at 25" do
        30.times { |i| create(:event, name: "Org #{i}") }

        search(q: "")

        expect(response).to have_http_status(:ok)
        expect(options.size).to eq(25)
      end
    end

    it "caps a query's results at 25" do
      sign_in_admin
      30.times { |i| create(:event, name: "YSWS - Project #{i}") }

      search

      expect(options.size).to eq(25)
    end

    context "as a non-admin organizer" do
      it "only returns orgs the caller manages, labelled without the id" do
        user = create(:user)
        mine = create(:event, name: "YSWS - Mine")
        create(:organizer_position, user:, event: mine)
        create(:event, name: "YSWS - Someone else's")
        create(:event, name: "YSWS")
        create_session(user, verified: true)

        search

        expect(labels).to eq(["YSWS - Mine"])
      end

      it "ranks an exact match the caller manages above their other orgs" do
        user = create(:user)
        create(:organizer_position, user:, event: create(:event, name: "YSWS - Project A"))
        exact = create(:event, name: "YSWS")
        create(:organizer_position, user:, event: exact)
        create_session(user, verified: true)

        search

        expect(labels.first).to eq("YSWS")
      end
    end
  end
end
