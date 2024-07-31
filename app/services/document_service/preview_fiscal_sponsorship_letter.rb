# frozen_string_literal: true

module DocumentService
  class PreviewFiscalSponsorshipLetter
    def initialize(event:)
      @event = event
    end

    def run
      IO.popen(cmd, err: File::NULL).read
    end

    private

    def pdf_string
      @pdf_string ||= ActionController::Base.new.tap { |c| c.instance_variable_set(:@event, @event) }.render_to_string pdf: "fiscal_sponsorship_letter", template: "documents/fiscal_sponsorship_letter", encoding: "UTF-8", formats: :pdf
    end

    def input
      @input ||= begin
        input = Tempfile.new(["fiscal_sponsorship_letter_preview", ".pdf"])
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
