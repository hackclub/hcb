# frozen_string_literal: true

class ConfigurationIntegrityMailerPreview < ActionMailer::Preview
  def taxbandits_leaking_tins
    ConfigurationIntegrityMailer.with(payee_ref: "tfm_dummy").taxbandits_leaking_tins
  end

  def check_failed
    ConfigurationIntegrityMailer.with(
      check: "ConfigurationIntegrity::Taxbandits::MaskedTinCheckJob",
      reason: "Couldn't read the dummy W-9's PDF (PayeeRef tfm_dummy) (PDF::Reader::MalformedPDFError)."
    ).check_failed
  end

end
