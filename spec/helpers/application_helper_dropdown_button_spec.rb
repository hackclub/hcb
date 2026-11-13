# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#dropdown_button" do
    let(:options) do
      [
        ["Standard expense", "standard", "Expense with a monetary amount."],
        ["Mileage expense", "mileage", "Expense for miles traveled."]
      ]
    end

    def render_dropdown(**kwargs)
      html = helper.form_with(url: "/expenses") do |form|
        helper.dropdown_button(form:, options:, name: "type", button_icon: "plus", template: ->(value) { "Add #{value} expense" }, **kwargs)
      end
      Nokogiri::HTML5.fragment(html)
    end

    it "renders a label per option and checks the first option's radio" do
      page = render_dropdown

      expect(page.css(".dropdown-button__label").map(&:text)).to eq(["Add standard expense", "Add mileage expense"])
      radios = page.css(".dropdown-button__menu input[type=radio][name=type]")
      expect(radios.map { |radio| [radio["value"], radio.key?("checked")] }).to eq([["standard", true], ["mileage", false]])
      expect(page.css(".dropdown-button__menu label strong").map(&:text)).to eq(["Standard expense", "Mileage expense"])
    end

    it "opens and closes the menu with herb state instead of a Stimulus controller" do
      page = render_dropdown

      expect(page.at_css(".dropdown-button")["data-herb-set"]).to eq("click@outside->menu_open=false")
      expect(page.at_css(".dropdown-button__menu")).to have_attribute("hidden")
      expect(page.css("[data-herb-toggle='menu_open']").size).to eq(1)
      expect(page.css("[data-controller]")).to be_empty
    end

    it "applies the caller's attributes to the button and its container" do
      page = render_dropdown(
        class: "w-full",
        button_options: { type: "button", disabled: true, data: { action: "tiptap#submit" } },
        button_container_options: { data: { "file-drop-target": "dropzone" } }
      )

      expect(page.at_css(".dropdown-button")["class"]).to include("w-full")
      expect(page.at_css(".dropdown-button__container")["data-file-drop-target"]).to eq("dropzone")
      main = page.at_css(".dropdown-button__container > button")
      expect(main["type"]).to eq("button")
      expect(main).to have_attribute("disabled")
      expect(main["data-action"]).to eq("tiptap#submit")
    end
  end
end
