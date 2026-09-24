# frozen_string_literal: true

require "rails_helper"

RSpec.describe SuborganizationsController do
  include SessionSupport

  describe "#new" do
    render_views

    let(:user) { create(:user) }
    let(:event) { create(:event) }

    before do
      create(:organizer_position, user:, event:)
      event.config.update!(subevent_plan: Event::Plan::Standard.name)
      create_session(user, verified: true)
    end

    def name_field_value(body)
      Nokogiri::HTML5(body).at_css("input#name")&.[]("value")
    end

    it "prefills the name field with the configured prefix" do
      event.config.update!(subevent_name_prefix: "Athena Award — ")

      get(:new, params: { event_id: event.slug })

      expect(name_field_value(response.body)).to eq("Athena Award — ")
    end

    it "leaves the name field empty when no prefix is configured" do
      get(:new, params: { event_id: event.slug })

      expect(name_field_value(response.body)).to be_blank
    end

    it "prefers an explicitly passed name over the prefix" do
      event.config.update!(subevent_name_prefix: "Athena Award — ")

      get(:new, params: { event_id: event.slug, name: "Hack Night" })

      expect(name_field_value(response.body)).to eq("Hack Night")
    end
  end

end
