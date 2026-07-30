# frozen_string_literal: true

require "rails_helper"

# The admin transfer tables open these screens in the shared popover, which
# fetches them as a turbo frame. Each one must render both ways.
RSpec.describe AdminController, type: :controller do
  include SessionSupport
  render_views

  before { create_session(create(:user, :make_admin), verified: true) }

  # An ACH transfer is only valid if its org can cover it.
  def create_transfer(factory)
    return create(factory) unless factory == :ach_transfer

    create(:ach_transfer, event: create(:event, :with_positive_balance))
  end

  # Only these two transfer types have factories; the rest are covered by the
  # PopoverHelper spec plus erb_lint.
  { ach_start_approval: :ach_transfer, disbursement_process: :disbursement }.each do |action, factory|
    context "##{action}" do
      it "renders standalone, with the layout" do
        transfer = create_transfer(factory)

        get action, params: { id: transfer.id }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("HCB Admin")
      end

      it "renders as the popover's frame, without the layout" do
        transfer = create_transfer(factory)
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
    transfer = create_transfer(:ach_transfer)

    get :ach_start_approval, params: { id: transfer.id }

    expect(response.body).to include(%(action="#{toggle_speed_ach_transfer_path(transfer)}"))
    expect(response.body).not_to include(%(data-turbo-method="post"))
  end

  it "opens the ACH review in the popover from the transfers table" do
    transfer = create_transfer(:ach_transfer)

    get :ach

    expect(response.body).to include(%(data-behavior="modal_trigger"))
    expect(response.body).to include(%(data-modal="shared_popover"))
    expect(response.body).to include(%(data-popover-frame-id="ach_transfer_process_#{transfer.id}"))
  end
end
