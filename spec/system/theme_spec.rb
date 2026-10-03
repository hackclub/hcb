# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Theme", type: :system do
  include SystemSessionSupport

  let(:user) { create(:user, phone_number: "+18556254225") }

  def choose_theme(theme)
    find(".user-menu-trigger").click
    find("[data-dark-mode-toggle-target=toggle][data-value=#{theme}]").click
  end

  def emulate_os_theme(theme)
    page.driver.browser.page.command("Emulation.setEmulatedMedia", features: [{ name: "prefers-color-scheme", value: theme }])
  end

  def expect_dark(dark)
    expect(page).to have_css("html[data-dark='#{dark}']", visible: :all)
  end

  before do
    sign_in(user)
    visit my_reimbursements_path
  end

  it "keeps a chosen theme across reloads whatever the OS theme is" do
    emulate_os_theme("light")
    choose_theme("dark")
    expect_dark(true)
    refresh
    expect_dark(true)

    emulate_os_theme("dark")
    choose_theme("light")
    expect_dark(false)
    refresh
    expect_dark(false)
  end

  it "follows the OS theme on System, both live and after a reload" do
    emulate_os_theme("light")
    choose_theme("system")
    expect_dark(false)

    emulate_os_theme("dark")
    expect_dark(true)
    refresh
    expect_dark(true)

    emulate_os_theme("light")
    expect_dark(false)
  end
end
