# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:each) do
    allow(TaxbanditsService).to receive(:create_whcertificate).and_return({})
    allow(TaxbanditsService).to receive(:get_submission).and_return(nil)
    allow(TaxbanditsService).to receive(:get_status).and_return(nil)
    allow(TaxbanditsService).to receive(:taxbandits_access_token).and_return("fake_token")
  end
end
