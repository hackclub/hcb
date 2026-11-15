# frozen_string_literal: true

module TurboStreamFlash
  private

  # Shows the updated `flash` by rendering a turbo stream which replaces the DOM
  # element which contains flash messages.
  #
  # ⚠️ Because this method renders immediately you should set your message with
  # `flash.now` before calling it.
  #
  # This can be particularly handy if you want to handle simple user
  # interactions that can occur on multiple pages with a single controller
  # action (e.g. `CanonicalTransactionsController#set_category`).
  def update_flash_via_turbo_stream(use_admin_layout: false)
    partial =
      if use_admin_layout
        "admin/flash"
      else
        "application/flash"
      end

    render(turbo_stream: turbo_stream.replace("flash-container", partial:))
  end
end
