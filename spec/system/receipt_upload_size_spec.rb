# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Receipt upload size check", type: :system do
  let(:user) { create(:user) }

  before do
    sign_in(user)
    visit my_inbox_path
  end

  around do |example|
    Tempfile.create(["big", ".png"]) do |file|
      file.truncate(Receipt::MAX_FILE_SIZE + 1) # sparse, so nothing is written to disk
      @big_file = file
      example.run
    end
  end

  let(:message) { "#{File.basename(@big_file.path)} is over 50 MB. Upload a smaller file." }

  # Builds a DataTransfer in the page holding the big file, via a scratch input Capybara can attach to
  def dispatch_with_big_file(event_js)
    page.execute_script(<<~JS)
      const input = document.createElement("input")
      input.type = "file"
      input.id = "qa_source"
      document.body.append(input)
    JS
    attach_file "qa_source", @big_file.path
    page.execute_script(<<~JS)
      const dt = new DataTransfer()
      dt.items.add(document.getElementById("qa_source").files[0])
      const form = document.querySelector("form.my-inbox-dropzone")
      #{event_js}
    JS
  end

  it "rejects a file over the limit before uploading it" do
    expect {
      attach_file "file", @big_file.path, make_visible: true
      expect(page).to have_css("[role=alert]", exact_text: message)
    }.not_to change(ActiveStorage::Blob, :count)

    expect(find_field("file", visible: :all).value).to be_blank
  end

  it "says nothing was uploaded when the oversized file was picked with others" do
    expect {
      attach_file "file", [@big_file.path, Rails.root.join("spec/fixtures/files/receipt.png").to_s], make_visible: true
      expect(page).to have_css("[role=alert]", exact_text: "#{File.basename(@big_file.path)} is over 50 MB, so nothing was uploaded. Upload a smaller file.")
    }.not_to change(ActiveStorage::Blob, :count)
  end

  it "rejects an oversized drop" do
    expect {
      dispatch_with_big_file(%(form.dispatchEvent(new DragEvent("drop", { dataTransfer: dt, bubbles: true, cancelable: true }))))
      expect(page).to have_css("[role=alert]", exact_text: message)
    }.not_to change(ActiveStorage::Blob, :count)

    expect(find_field("file", visible: :all).value).to be_blank
  end

  it "rejects an oversized paste" do
    expect {
      dispatch_with_big_file(%(document.body.dispatchEvent(new ClipboardEvent("paste", { clipboardData: dt, bubbles: true }))))
      expect(page).to have_css("[role=alert]", exact_text: message)
    }.not_to change(ActiveStorage::Blob, :count)

    expect(find_field("file", visible: :all).value).to be_blank
  end

  it "hides the message and uploads a valid file chosen afterwards" do
    attach_file "file", @big_file.path, make_visible: true
    expect(page).to have_css("[role=alert]", text: "is over 50 MB")

    attach_file "file", Rails.root.join("spec/fixtures/files/receipt.png"), make_visible: true
    expect(page).to have_no_css("[role=alert]", visible: :visible)

    # The check gates the direct upload; its PUT goes to the Disk service host, which the spec driver blocks
    Timeout.timeout(Capybara.default_max_wait_time) { sleep 0.1 until ActiveStorage::Blob.exists?(filename: "receipt.png") }
    expect(ActiveStorage::Blob.where("filename LIKE 'big%'")).to be_empty
  end
end
