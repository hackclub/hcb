# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::EventGroupsController do
  include SessionSupport
  render_views

  describe "#index" do
    it "renders a list of groups along with their owners and events" do
      orpheus = create(:user, :make_admin, full_name: "Orpheus Dinosaur")
      scrapyard = Event::Group.create!(user: orpheus, name: "Scrapyard")
      scrapyard.memberships.create!(event: create(:event, name: "Scrapyard Vermont"))
      scrapyard.memberships.create!(event: create(:event, name: "Scrapyard London"))

      barney = create(:user, :make_admin, full_name: "Barney Dinosaur")
      daydream = Event::Group.create!(user: barney, name: "Daydream")
      daydream.memberships.create!(event: create(:event, name: "Daydream Ottawa"))

      sign_in(orpheus)

      get(:index)

      expect(response).to have_http_status(:ok)

      rows =
        response
        .parsed_body
        .css("table tbody tr")
        .map { |tr| inspect_row(tr).take(3) }

      expect(rows).to eq(
        [
          [["Name", "Daydream"], ["Owner", "Barney Dinosaur"], ["Events", "Daydream Ottawa ×"]],
          [["Name", "Scrapyard"], ["Owner", "You"], ["Events", "Scrapyard London × Scrapyard Vermont ×"]]
        ]
      )
    end
  end

  describe "#create" do
    it "creates a new group owned by the current user" do
      user = create(:user, :make_admin)
      sign_in(user)

      post(:create, params: { event_group: { name: "Scrapyard" } })

      expect(response).to redirect_to(admin_event_groups_path)
      expect(flash[:success]).to eq("Group created")

      group = Event::Group.last
      expect(group.user).to eq(user)
      expect(group.name).to eq("Scrapyard")
    end

    it "reports an error if there are validation issues" do
      user = create(:user, :make_admin)
      sign_in(user)

      post(:create, params: { event_group: { name: "" } })

      expect(response).to redirect_to(admin_event_groups_path)
      expect(flash[:error]).to eq("Name can't be blank")
    end
  end

  describe "#destroy" do
    it "deletes the group along with its memberships" do
      user = create(:user, :make_admin)
      sign_in(user)

      event = create(:event)
      group = user.event_groups.create!(name: "Scrapyard")
      group.memberships.create!(event:)

      delete(:destroy, params: { id: group.id })

      expect(response).to redirect_to(admin_event_groups_path)
      expect(flash[:success]).to eq("Group successfully deleted")

      expect(Event::Group.find_by(id: group.id)).to be_nil
    end
  end

  def inspect_row(row)
    table = row.ancestors("table")
    headers = table.css("thead tr th").map { |th| th.text.squish }
    values = row.css("td").map { |td| td.text.squish }

    headers.zip(values)
  end

end
