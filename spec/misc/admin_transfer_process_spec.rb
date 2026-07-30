# frozen_string_literal: true

require "rails_helper"

# The admin transfer tables open these screens in the shared popover, which
# fetches them as a turbo frame. Each one must render both ways.
#
# Only ACH transfers and disbursements have factories, so the rest are built
# here with `save!(validate: false)` — enough of a record to render the view,
# without reimplementing each model's full validation surface.
RSpec.describe AdminController, type: :controller do
  include SessionSupport
  render_views

  let(:event) { create(:event, :with_positive_balance) }
  let(:user) { create(:user) }

  before { create_session(create(:user, :make_admin), verified: true) }

  def build_transfer(kind)
    record =
      case kind
      when :ach_transfer then create(:ach_transfer, event:)
      when :disbursement then create(:disbursement)
      when :wire then Wire.new(**common_attrs, **address_attrs, currency: "USD", bic_code: "HIBKUS44", account_number: "111111111", memo: "Venue")
      when :paypal_transfer then PaypalTransfer.new(**common_attrs, memo: "Venue")
      when :increase_check then IncreaseCheck.new(event:, user:, amount: 5_500, recipient_name: "Orpheus", recipient_email: "payee@example.com", memo: "Venue", payment_for: "Venue deposit", address_line1: "24 New Hampshire", address_city: "Irvine", address_state: "CA", address_zip: "92602")
      when :wise_transfer
        # Creating one for real fetches a live quote from Wise.
        allow_any_instance_of(WiseTransfer).to receive(:generate_quote!)
        WiseTransfer.new(**common_attrs, **address_attrs, currency: "USD", quoted_usd_amount_cents: 5_500)
      end

    record.save!(validate: false) unless record.persisted?
    record
  end

  def common_attrs
    { event:, user:, amount_cents: 5_500, recipient_name: "Orpheus", recipient_email: "payee@example.com", payment_for: "Venue deposit" }
  end

  def address_attrs
    { address_line1: "24 New Hampshire", address_city: "Irvine", address_state: "CA", address_postal_code: "92602", recipient_country: "US" }
  end

  {
    ach_start_approval: :ach_transfer,
    disbursement_process: :disbursement,
    wire_process: :wire,
    wise_transfer_process: :wise_transfer,
    paypal_transfer_process: :paypal_transfer,
    increase_check_process: :increase_check,
  }.each do |action, kind|
    context "##{action}" do
      it "renders standalone, with the layout" do
        transfer = build_transfer(kind)

        get action, params: { id: transfer.id }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("HCB Admin")
      end

      it "renders as the popover's frame, without the layout" do
        transfer = build_transfer(kind)
        frame_id = "#{transfer.class.name.underscore}_process_#{transfer.id}"
        request.headers["Turbo-Frame"] = frame_id

        get action, params: { id: transfer.id }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(%(id="#{frame_id}"))
        expect(response.body).not_to include("HCB Admin")
      end
    end
  end

  # `data-turbo-method` links only POST if Turbo intercepts the click; a plain
  # GET on this path has no matching route, so it must be a real form.
  it "toggles ACH speed with a POST form, not a link" do
    transfer = build_transfer(:ach_transfer)

    get :ach_start_approval, params: { id: transfer.id }

    expect(response.body).to include(%(action="#{toggle_speed_ach_transfer_path(transfer)}"))
    expect(response.body).not_to include(%(data-turbo-method="post"))
  end

  it "opens the ACH review in the popover from the transfers table" do
    transfer = build_transfer(:ach_transfer)

    get :ach

    expect(response.body).to include(%(data-behavior="modal_trigger"))
    expect(response.body).to include(%(data-modal="shared_popover"))
    expect(response.body).to include(%(data-popover-frame-id="ach_transfer_process_#{transfer.id}"))
  end
end
