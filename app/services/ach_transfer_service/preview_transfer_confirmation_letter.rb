# frozen_string_literal: true

module AchTransferService
  class PreviewTransferConfirmationLetter
    def initialize(ach_transfer:, event:)
      @ach_transfer = ach_transfer
      @event = event
    end

    def run
      IO.popen(cmd, err: File::NULL).read
    end

    private

    def pdf_string
      @pdf_string ||= ApplicationController.new.render_to_string pdf: "transfer_confirmation_letter", template: "ach_transfers/transfer_confirmation_letter", encoding: "UTF-8", locals: { :@ach_transfer => @ach_transfer, :@event => @event }, formats: :pdf
    end

    def input
      @input ||= begin
        input = Tempfile.new(["transfer_confirmation_letter_preview", ".pdf"])
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
