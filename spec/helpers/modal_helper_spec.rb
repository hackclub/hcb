# frozen_string_literal: true

require "rails_helper"

RSpec.describe ModalHelper, type: :helper do
  describe "#modal" do
    def render_modal(*, **) = Nokogiri::HTML.fragment(helper.modal(*, **) { "Body" })

    it "renders a dialog labelled by its title, with the block as its body" do
      dialog = render_modal("Rename card", id: "rename_card").at_css("dialog")

      expect(dialog["id"]).to eq("rename_card")
      expect(dialog["aria-labelledby"]).to eq("rename_card_title")
      expect(dialog.at_css("h2#rename_card_title").text).to eq("Rename card")
      expect(dialog.at_css("button[data-modal-close][type=button]")).to be_present
      expect(dialog.text).to include("Body")
    end

    # Titles are often built from record names that users control
    it "strips script from a title while keeping its markup" do
      dialog = render_modal(%(<em>Payment</em><img src=x onerror="alert(1)"><script>alert(2)</script>), id: "payment").at_css("dialog")

      expect(dialog.at_css("h2 em").text).to eq("Payment")
      expect(dialog.at_css("[onerror], script")).to be_nil
    end

    it "escapes an id that tries to break out of its attribute" do
      dialog = render_modal(id: %(x" onmouseover="alert(1)), size: :wide).at_css("dialog")

      expect(dialog["id"]).to eq(%(x" onmouseover="alert(1)))
      expect(dialog["onmouseover"]).to be_nil
    end

    it "adds the caller's classes and controllers to its own instead of replacing them" do
      dialog = render_modal(id: "picker", size: :wide, class: "max-w-md", open: true, data: { controller: "picker", picker_value: 1 }).at_css("dialog")

      expect(dialog["class"].split).to eq(%w[modal modal--scroll bg-snow modal--wide max-w-md])
      expect(dialog["data-controller"]).to eq("picker open-modal")
      expect(dialog["data-turbo-temporary"]).to eq("true")
      expect(dialog["data-picker-value"]).to eq("1")
    end

    it "leaves out what a modal without a title, size or auto-open doesn't need" do
      dialog = render_modal(id: "bare").at_css("dialog")

      expect(dialog["class"]).to eq("modal modal--scroll bg-snow")
      expect(dialog.attributes.keys).to contain_exactly("id", "class")
      expect(dialog.at_css("header")).to be_nil
    end
  end
end
