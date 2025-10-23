# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::EventGroupsController do
  include SessionSupport
  render_views

  describe "#index" do
    it "renders a list of groups along with their owners and events" do
      orpheus = create(:user, :make_admin, full_name: "Orpheus Dinosaur")
      scrapyard = create(:event_group, user: orpheus, name: "Scrapyard")
      scrapyard.memberships.create!(event: create(:event, name: "Scrapyard Vermont"))
      scrapyard.memberships.create!(event: create(:event, name: "Scrapyard London"))

      barney = create(:user, :make_admin, full_name: "Barney Dinosaur")
      daydream = create(:event_group, user: barney, name: "Daydream")
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
          [["Name", "Daydream"], ["Owner", "Barney Dinosaur"], ["Events", "Daydream Ottawa"]],
          [["Name", "Scrapyard"], ["Owner", "You"], ["Events", "Scrapyard London Scrapyard Vermont"]]
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

  describe "#event" do
    it "renders a form with checkboxes for each group" do
      user = create(:user, :make_admin, full_name: "Orpheus Dinosaur")
      scrapyard = user.event_groups.create!(name: "Scrapyard")
      daydream = user.event_groups.create!(name: "Daydream")

      event = create(:event)
      daydream.memberships.create!(event:)

      sign_in(user)

      get(:event, params: { event_id: event.id })

      expect(response).to have_http_status(:ok)

      rows = response.parsed_body.css("table tbody tr")

      daydream_input = rows[0].at_css("input[name='event[event_group_ids][]']")
      expect(daydream_input["value"]).to eq(daydream.id.to_s)
      expect(daydream_input["checked"]).to eq("checked")
      expect(rows[0].at_css("label").text.squish).to eq("Daydream (Orpheus Dinosaur)")

      scrapyard_input = rows[1].at_css("input[name='event[event_group_ids][]']")
      expect(scrapyard_input["value"]).to eq(scrapyard.id.to_s)
      expect(scrapyard_input["checked"]).to be_nil
      expect(rows[1].at_css("label").text.squish).to eq("Scrapyard (Orpheus Dinosaur)")

    end
  end

  describe "#update_event" do
    it "clears out unselected groups" do
      user = create(:user, :make_admin)
      sign_in(user)

      event = create(:event)

      group1 = user.event_groups.create!(name: "Group 1")
      group1.memberships.create!(event:)

      group2 = user.event_groups.create!(name: "Group 2")
      group2.memberships.create!(event:)

      patch(
        :update_event,
        params: {
          event_id: event.id,
        }
      )

      expect(response).to redirect_to(event_admin_event_groups_path(event))
      expect(group1.reload.events).to be_empty
      expect(group2.reload.events).to be_empty

    end

    it "adds selected groups and maintains existing ones" do
      user = create(:user, :make_admin)
      sign_in(user)

      event = create(:event)

      # Group 1 will be preserved
      group1 = user.event_groups.create!(name: "Group 1")
      group1.memberships.create!(event:)

      # Group 2 will be removed
      group2 = user.event_groups.create!(name: "Group 2")
      group2.memberships.create!(event:)

      # Group 3 will be added
      group3 = user.event_groups.create!(name: "Group 3")

      patch(
        :update_event,
        params: {
          event_id: event.id,
          event: {
            event_group_ids: [group1.id, group3.id]
          }
        }
      )

      expect(response).to redirect_to(event_admin_event_groups_path(event))
      expect(group1.reload.events).to include(event)
      expect(group2.reload.events).to be_empty
      expect(group3.reload.events).to include(event)
    end

    it "adds a new group" do
      user = create(:user, :make_admin)
      sign_in(user)

      event = create(:event)

      patch(
        :update_event,
        params: {
          event_id: event.id,
          event: {
            new_event_group_name: "Scrapyard"
          }
        }
      )

      expect(response).to redirect_to(event_admin_event_groups_path(event))
      group = user.reload.event_groups.last
      expect(group.events).to include(event)
      expect(group.user).to eq(user)
      expect(group.name).to eq("Scrapyard")
    end
  end

  def inspect_row(row)
    table = row.ancestors("table")
    headers = table.css("thead tr th").map { |th| th.text.squish }
    values = row.css("td").map { |td| td.text.squish }

    headers.zip(values)
  end

end
