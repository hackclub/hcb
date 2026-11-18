# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Receipt upload size check", type: :system do
  let(:user) { create(:user) }

  before do
    sign_in(user)
    visit my_inbox_path
  end

  it "rejects a file over the limit before uploading it" do
    Tempfile.create(["big", ".png"]) do |file|
      file.truncate(Receipt::MAX_FILE_SIZE + 1) # sparse, so nothing is written to disk

      expect {
        attach_file "file", file.path, make_visible: true
        expect(page).to have_css("[role=alert]", text: "#{File.basename(file.path)} is larger than the 50 MB limit")
      }.not_to change(ActiveStorage::Blob, :count)

      expect(find_field("file", visible: :all).value).to be_blank
    end
  end
end
