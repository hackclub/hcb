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

      # Both orgs are prefix matches, and the decoy has the shorter name, so
      # only a case-insensitive exact match can lift the real one to the top.
      it "matches case-insensitively" do
        decoy = create(:event, name: "Bee", slug: "ysws-hq-extras")
        exact = create(:event, name: "YSWS-HQ")

        search(q: "YSWS-hq")

        expect(labels).to eq([exact, decoy].map { |event| admin_label(event) })
      end

      # The renamed org has the longer name, so only an exact match on its slug
      # can rank it above an org whose name merely starts with the query.
      it "ranks an exact slug match above a mere prefix match on a name" do
        prefixed = create(:event, name: "ysws-hq extras")
        renamed = create(:event, name: "Renamed Organisation With A Long Name", slug: "ysws-hq")

        search(q: "ysws-hq")

        expect(labels).to eq([renamed, prefixed].map { |event| admin_label(event) })
      end

      # Only a prefix match on the renamed org's slug can rank its longer name
      # above an org whose name merely contains the query.
      it "ranks a prefix match on a slug above a substring match on a name" do
        substring = create(:event, name: "x ysws-hq")
        renamed = create(:event, name: "Renamed Organisation With A Long Name", slug: "ysws-hq-team")

        search(q: "ysws-hq")

        expect(labels).to eq([renamed, substring].map { |event| admin_label(event) })
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

      # Equal-length names, so only the caller's preference can order these.
      it "keeps the caller's own orgs first within a rank" do
        theirs = create(:event, name: "YSWS - Alpha")
        mine = create(:event, name: "YSWS - Omega")
        create(:organizer_position, user: @admin, event: mine)
        exact = create(:event, name: "YSWS")

        search

        expect(labels).to eq([exact, mine, theirs].map { |event| admin_label(event) })
      end

      # "ysw" is a prefix of every candidate, so the tiers cannot separate them
      # and the shortest name has to win before the caller's own orgs do.
      it "surfaces the shortest name for a partial prefix the caller does not organize" do
        long = create(:event, name: "YSWS - asdf")
        longer = create(:event, name: "ysws - asdlfkhjasdlfhd")
        [long, longer].each { |event| create(:organizer_position, user: @admin, event:) }
        short = create(:event, name: "YSWS")

        search(q: "ysw")

        expect(labels).to eq([short, long, longer].map { |event| admin_label(event) })
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

      # An unescaped "_" in the prefix pattern would match any character, so
      # this shorter non-prefix org would tie for the top rank and win on
      # length despite not actually starting with the query.
      it "treats wildcards as literal when ranking prefix matches" do
        decoy = create(:event, name: "AXB A_B")
        literal_prefix = create(:event, name: "A_B Club Of Greater Somewhere")

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
