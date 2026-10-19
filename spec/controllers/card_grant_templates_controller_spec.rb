# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardGrantTemplatesController do
  include SessionSupport
  render_views

  def form_params
    {
      email: "recipient@example.com",
      amount_cents: "42.50",
      purpose: "Pizza night",
      instructions: "Only buy pizza",
      invite_message: "Enjoy!",
      one_time_use: "1",
      pre_authorization_required: "0",
      merchant_lock: "123, 456",
      category_lock: "",
      keyword_lock: "",
      banned_merchants: "",
      banned_categories: "betting_casino_gambling",
    }
  end

  def setup_event(role: :manager)
    user = create(:user)
    event = create(:event, plan_type: Event::Plan::HackClubAffiliate)
    create(:card_grant_setting, event:)
    create(:organizer_position, user:, event:, role:)
    create_session(user, verified: true)

    [user, event]
  end

  describe "#create" do
    it "saves the form as a template without the recipient's email" do
      user, event = setup_event

      post(:create, params: { event_id: event.friendly_id, template_name: "Pizza", card_grant: form_params })

      template = event.card_grant_templates.sole
      expect(response).to redirect_to(new_event_card_grant_path(event, template_id: template.hashid))
      expect(template.name).to eq("Pizza")
      expect(template.created_by).to eq(user)
      expect(template.amount_cents).to eq(42_50)
      expect(template.purpose).to eq("Pizza night")
      expect(template.instructions).to eq("Only buy pizza")
      expect(template.invite_message).to eq("Enjoy!")
      expect(template.one_time_use).to eq(true)
      expect(template.pre_authorization_required).to eq(false)
      expect(template.merchant_lock).to eq(["123", "456"])
      expect(template.category_lock).to eq([])
      expect(template.keyword_lock).to be_nil
      expect(template.banned_categories).to eq(["betting_casino_gambling"])
      expect(template.attributes.values).not_to include("recipient@example.com")
    end

    it "allows a blank amount" do
      _user, event = setup_event

      post(:create, params: { event_id: event.friendly_id, template_name: "No amount", card_grant: { **form_params, amount_cents: "" } })

      expect(event.card_grant_templates.sole.amount_cents).to be_nil
    end

    it "re-renders the form when the template is invalid" do
      _user, event = setup_event

      post(:create, params: { event_id: event.friendly_id, template_name: "", card_grant: form_params })

      expect(response).to have_http_status(:unprocessable_content)
      expect(flash[:error]).to eq("Name can't be blank")
      expect(event.card_grant_templates).to be_empty
      expect(response.parsed_body.at_css("[name='card_grant[email]']")["value"]).to eq("recipient@example.com")
      expect(response.parsed_body.at_css("[name='card_grant[purpose]']")["value"]).to eq("Pizza night")
    end

    it "rejects a name already used by another template, ignoring case" do
      _user, event = setup_event
      create(:card_grant_template, event:, name: "Pizza")

      post(:create, params: { event_id: event.friendly_id, template_name: "PIZZA", card_grant: form_params })

      expect(response).to have_http_status(:unprocessable_content)
      expect(flash[:error]).to eq("Name has already been taken")
      expect(event.card_grant_templates.count).to eq(1)
      expect(response.parsed_body.at_css("[name='template_name']")["value"]).to eq("PIZZA")
    end

    it "treats a database uniqueness violation as a taken name" do
      _user, event = setup_event
      allow_any_instance_of(CardGrantTemplate).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)

      post(:create, params: { event_id: event.friendly_id, template_name: "Pizza", card_grant: form_params })

      expect(response).to have_http_status(:unprocessable_content)
      expect(flash[:error]).to eq("Name has already been taken")
    end

    it "keeps the previously applied template when saving a new one fails" do
      _user, event = setup_event
      applied = create(:card_grant_template, event:, name: "Applied")

      post(:create, params: { event_id: event.friendly_id, template_name: "", template_id: applied.hashid, card_grant: form_params })

      expect(response).to have_http_status(:unprocessable_content)
      body = response.parsed_body
      expect(body.at_css("[name='template_id']")["value"]).to eq(applied.hashid)
      expect(body.at_css("button[formaction='#{event_card_grant_template_path(event, applied)}']")).to be_present
    end

    it "rejects an invalid merchant name lock" do
      _user, event = setup_event

      post(:create, params: { event_id: event.friendly_id, template_name: "Pizza", card_grant: { **form_params, keyword_lock: "[unclosed" } })

      expect(response).to have_http_status(:unprocessable_content)
      expect(flash[:error]).to eq("Keyword lock is not a valid regular expression")
      expect(event.card_grant_templates).to be_empty
    end

    it "rejects a huge amount without raising" do
      _user, event = setup_event

      post(:create, params: { event_id: event.friendly_id, template_name: "Pizza", card_grant: { **form_params, amount_cents: "99999999999" } })

      expect(response).to have_http_status(:unprocessable_content)
      expect(flash[:error]).to eq("Amount cents is too big")
      expect(event.card_grant_templates).to be_empty
    end

    it "doesn't raise when the template name isn't a string" do
      _user, event = setup_event

      post(:create, params: { event_id: event.friendly_id, template_name: ["Pizza"], card_grant: form_params })

      expect(response).to have_http_status(:unprocessable_content)
      expect(event.card_grant_templates).to be_empty
    end

    it "doesn't allow readers to save templates" do
      _user, event = setup_event(role: :reader)

      post(:create, params: { event_id: event.friendly_id, template_name: "Pizza", card_grant: form_params })

      expect(flash[:error]).to match(/not authorized/i)
      expect(event.card_grant_templates).to be_empty
    end
  end

  describe "#update" do
    it "replaces the template's settings with the form's" do
      _user, event = setup_event
      template = create(:card_grant_template, event:, name: "Pizza", amount_cents: 10_00, purpose: "Old purpose")

      patch(:update, params: { event_id: event.friendly_id, id: template.hashid, card_grant: form_params })

      expect(response).to redirect_to(new_event_card_grant_path(event, template_id: template.hashid))
      template.reload
      expect(template.name).to eq("Pizza")
      expect(template.amount_cents).to eq(42_50)
      expect(template.purpose).to eq("Pizza night")
    end

    it "never stores the recipient's email" do
      _user, event = setup_event
      template = create(:card_grant_template, event:)

      patch(:update, params: { event_id: event.friendly_id, id: template.hashid, card_grant: form_params })

      expect(template.reload.attributes.values).not_to include("recipient@example.com")
    end

    it "doesn't allow readers to update templates" do
      _user, event = setup_event(role: :reader)
      template = create(:card_grant_template, event:, purpose: "Untouched")

      patch(:update, params: { event_id: event.friendly_id, id: template.hashid, card_grant: form_params })

      expect(flash[:error]).to match(/not authorized/i)
      expect(template.reload.purpose).to eq("Untouched")
    end

    it "can't update another event's template" do
      _user, event = setup_event
      other_template = create(:card_grant_template, purpose: "Untouched")

      expect {
        patch(:update, params: { event_id: event.friendly_id, id: other_template.hashid, card_grant: form_params })
      }.to raise_error(ActiveRecord::RecordNotFound)

      expect(other_template.reload.purpose).to eq("Untouched")
    end
  end

  describe "#destroy" do
    it "deletes the template" do
      _user, event = setup_event
      template = create(:card_grant_template, event:)

      delete(:destroy, params: { event_id: event.friendly_id, id: template.hashid })

      expect(response).to redirect_to(new_event_card_grant_path(event))
      expect(CardGrantTemplate.exists?(template.id)).to eq(false)
    end

    it "can't delete another event's template" do
      _user, event = setup_event
      other_template = create(:card_grant_template)

      expect {
        delete(:destroy, params: { event_id: event.friendly_id, id: other_template.hashid })
      }.to raise_error(ActiveRecord::RecordNotFound)

      expect(CardGrantTemplate.exists?(other_template.id)).to eq(true)
    end

    it "doesn't allow readers to delete templates" do
      _user, event = setup_event(role: :reader)
      template = create(:card_grant_template, event:)

      delete(:destroy, params: { event_id: event.friendly_id, id: template.hashid })

      expect(flash[:error]).to match(/not authorized/i)
      expect(CardGrantTemplate.exists?(template.id)).to eq(true)
    end
  end
end
