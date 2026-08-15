# frozen_string_literal: true

module LegalEntitiesHelper
  # Renders the last four digits of a TIN, and only ever to the taxpayer themselves.
  # Admins and auditors get a redaction instead: nobody but the payee may see any
  # part of a TIN. `viewable` gates the call itself, not just the output, because
  # reading a masked TIN costs a request to TaxBandits.
  #
  # fs-exclude keeps the digits out of FullStory session replay entirely, rather
  # than fs-mask, which still records the element.
  def masked_tin_tag(tax_form, viewable:)
    masked = tax_form&.masked_tin if viewable

    tag.code(masked.presence || "hidden", class: "whitespace-nowrap fs-exclude")
  end

end
