# frozen_string_literal: true

module DocumentService
  class PreviewVerificationLetter
    def initialize(event:, contract_signers:)
      @event = event
      @contract_signers = contract_signers
    end

    def run
      IO.popen(cmd, err: File::NULL).read
    end

    private

    def pdf_string
      @pdf_string ||= ActionController::Base.new.tap do |c|
        c.instance_variable_set(:@event, @event)
        c.instance_variable_set(:@contract_signers, @contract_signers)
      end.render_to_string pdf: "verification_letter", template: "documents/verification_letter", encoding: "UTF-8", formats: :pdf
    end

    def input
      @input ||= begin
        input = Tempfile.new(["verification_letter_preview", ".pdf"])
        input.binmode
        input.write(pdf_string)
        input.rewind

        input
      end
    end

    def cmd
      ["pdftoppm", "-singlefile", "-r", "72", "-png", input.path]
    end

  end
end
