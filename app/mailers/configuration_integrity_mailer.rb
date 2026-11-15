# frozen_string_literal: true

class ConfigurationIntegrityMailer < ApplicationMailer
  default to: ENGINEERING_EMAIL

  def taxbandits_leaking_tins
    @payee_ref = params.fetch(:payee_ref)

    mail subject: "[URGENT] TaxBandits leaking full TINs"
  end

  def check_failed
    @check = params.fetch(:check)
    @reason = params.fetch(:reason)

    mail subject: "Configuration integrity check couldn't run: #{@check}"
  end

end
