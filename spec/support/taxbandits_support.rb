# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:each) do
    allow_any_instance_of(Tax::Form).to receive(:taxbandits_access_token).and_return("fake_token")
    allow_any_instance_of(Tax::Form).to receive(:send_using_taxbandits!)
    allow_any_instance_of(Tax::Form).to receive(:taxbandits_submission).and_return(nil)
  end
end
