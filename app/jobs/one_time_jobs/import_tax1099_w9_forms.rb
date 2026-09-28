# frozen_string_literal: true

require "csv"

module OneTimeJobs
  # Interactive one-time script for importing W-9s collected via Tax1099 into
  # TaxBandits. Meant to be run by hand from a console/runner session (not
  # enqueued on the job queue), since it prompts on $stdin for every row:
  #
  #   OneTimeJobs::ImportTax1099W9Forms.new.perform("/path/to/export.csv")
  class ImportTax1099W9Forms < ApplicationJob
    # Row schema:
    # Payer Name, Payer TIN, Payee First Name, Payee Middle Name, Payee Last Name, Payee Suffix,
    # EIN/SSN, W9 Requested Date, W9 Received Date, Email Address, Mail Status (opened, delivered, rejected, etc),
    # Business Type, Filer Type, Address, City, State, Zip Code, Country, W9 Request, W9 Count,
    # W9 Completed Date, W9 Cancel Date
    # Tax1099 doesn't export a value we can trust for this, so it's never
    # prefilled from the CSV and must always be entered by hand.
    FEDERAL_TAX_CLASSIFICATIONS = [
      "Individual", "Sole Proprietor", "Single Member LLC Not Elected", "Single Member LLC Elected",
      "C Corporation", "S Corporation", "Partnership", "Trust or Estate", "LLC C Corporation",
      "LLC S Corporation", "LLC Partnership", "Others"
    ].freeze

    FIELDS = [
      { key: :first_name, label: "Payee First Name", required: true },
      { key: :middle_name, label: "Payee Middle Name", required: false },
      { key: :last_name, label: "Payee Last Name", required: false },
      { key: :suffix, label: "Payee Suffix", required: false },
      { key: :tin, label: "TIN (EIN/SSN)", required: true },
      { key: :tin_type, label: "TIN Type (SSN or EIN)", required: true },
      { key: :federal_tax_classification, label: "Federal Tax Classification", required: true,
        hint: "must be one of: #{FEDERAL_TAX_CLASSIFICATIONS.join(", ")}"
},
      { key: :address1, label: "Address", required: true },
      { key: :city, label: "City", required: true },
      { key: :state, label: "State", required: true },
      { key: :zip_code, label: "Zip Code", required: true },
      { key: :email, label: "Email Address", required: true },
    ].freeze

    def perform(csv_path)
      rows = CSV.read(csv_path)
      rows.shift # header row

      imported_count = 0
      manual_review_count = 0
      skipped_rows = []
      failed_rows = []

      rows.each_with_index do |row, i|
        row_number = i + 2 # +1 for the header row, +1 to make it 1-indexed

        puts
        puts "=" * 72
        puts "Row #{row_number}/#{rows.size + 1}"
        puts "=" * 72

        data = prefill(row)

        if (duplicate = duplicate_tax1099_form(data))
          puts "Skipping row #{row_number}: a tax1099 form for this TIN already exists (#{duplicate.public_id})."
          skipped_rows.push(row_number)
          next
        end

        unless prompt_for_row!(data)
          puts "Skipping row #{row_number}."
          skipped_rows.push(row_number)
          next
        end

        form = Tax::Form.create!(external_service: :taxbandits, source: :tax1099)
        payload = build_payload(form, data)

        begin
          tb_response = TaxbanditsService.create_from_data(payload)
        rescue => e
          puts "  ! Failed to submit row #{row_number} to TaxBandits: #{e.message}"
          form.destroy!
          failed_rows.push(row_number)
          next
        end

        form.update!(external_id: tb_response["SubmissionId"])
        imported_count += 1

        manual_review_count += 1 unless assign_legal_entity!(form, data)

        # The recipient never visits TaxBandits themselves (create_from_data
        # already submitted the completed form data on their behalf), so
        # nothing will ever call import_taxbandits_data for these forms. Set
        # what it would have derived directly, and mark the form complete now
        # rather than leaving it stuck pending forever.
        complete_form!(form, data)
        form.legal_entity&.refresh_pending_contractors_payments!
      end

      puts
      puts "-" * 72
      puts "Failed to import rows #{failed_rows.map { |r| "##{r}" }.join(", ")}" if failed_rows.any?
      puts "Skipped rows #{skipped_rows.map { |r| "##{r}" }.join(", ")}" if skipped_rows.any?
      puts "Successfully imported #{imported_count} forms"
      puts "#{manual_review_count} forms need manual legal entity assignment"
    end

    private

    def prefill(row)
      tin = row[6].to_s
      is_business = tin.count("-") != 2

      # Tax1099's export puts the business name in the "Payee Last Name"
      # column for business filers (there's no separate business-name
      # column), but TaxBandits expects the entity name in FirstNm for a
      # business FormW9, so it's moved over here rather than at submission
      # time so the interactive review below shows it in the right field.
      {
        first_name: is_business ? row[4].to_s : row[2].to_s,
        middle_name: row[3].to_s,
        last_name: is_business ? "" : row[4].to_s,
        suffix: row[5].to_s == "SEL" ? "" : row[5].to_s,
        tin:,
        tin_type: is_business ? "EIN" : "SSN",
        # An SSN filer can still be a sole proprietor, not just an individual,
        # so only prefill when Tax1099's Filer Type agrees it's an individual.
        federal_tax_classification: !is_business && row[12].to_s.strip.casecmp("Individual").zero? ? "Individual" : "",
        address1: row[13].to_s,
        city: row[14].to_s,
        state: row[15].to_s,
        zip_code: row[16].to_s,
        email: row[9].to_s
      }
    end

    # Shows the prefilled/edited data for a row and lets the user fix it up
    # before it's sent to TaxBandits. Returns false if the user chose to skip
    # the row entirely, true once the row has every required field filled in
    # and the user has confirmed it.
    def prompt_for_row!(data)
      loop do
        print_fields(data)

        missing = missing_fields(data)
        if missing.any?
          print("\nMissing required field(s): #{missing.join(", ")}. Enter a number to edit, or 's' to skip this row: ")
        else
          print("\nPress Enter to submit to TaxBandits, enter a number to edit a field, or 's' to skip this row: ")
        end

        input = $stdin.gets.to_s.strip

        return false if input.casecmp("s").zero?

        if input.empty?
          if missing.any?
            puts "Please fill in the missing required field(s) before submitting."
            next
          end

          return true
        end

        field = FIELDS[input.to_i - 1]
        if field.nil?
          puts "Invalid selection: #{input}"
          next
        end

        if field[:key] == :federal_tax_classification
          data[field[:key]] = prompt_federal_tax_classification(data[field[:key]])
        else
          puts "  (#{field[:hint]})" if field[:hint]
          print("#{field[:label]} [#{data[field[:key]]}]: ")
          new_value = $stdin.gets.to_s.strip
          data[field[:key]] = new_value unless new_value.empty?
        end
      end
    end

    def prompt_federal_tax_classification(current)
      FEDERAL_TAX_CLASSIFICATIONS.each_with_index { |classification, i| puts "    #{i + 1}. #{classification}" }
      print("Federal Tax Classification [#{current}]: ")

      input = $stdin.gets.to_s.strip
      return current if input.empty?

      FEDERAL_TAX_CLASSIFICATIONS[input.to_i - 1] || input
    end

    def print_fields(data)
      FIELDS.each_with_index do |field, i|
        flag = field[:required] && data[field[:key]].blank? ? " (required, missing)" : ""
        puts "  #{i + 1}. #{field[:label]}: #{data[field[:key]].presence || "-"}#{flag}"
        puts "       (#{field[:hint]})" if field[:hint]
      end
    end

    def missing_fields(data)
      FIELDS.select { |f| f[:required] && data[f[:key]].blank? }.map { |f| f[:label] }
    end

    def duplicate_tax1099_form(data)
      Tax::Form.tax1099.not_discarded.find_by(tin_hash: compute_tin_hash(data))
    end

    def entity_type_for(data)
      if data[:tin_type] == "SSN"
        :person
      elsif data[:federal_tax_classification].to_s.include?("Corporation")
        :corporation
      else
        :business
      end
    end

    def compute_tin_hash(data)
      Tax::IdentificationNumber::Hasher.hash_tin(
        data[:tin],
        tin_type: Tax::IdentificationNumber::Hasher.tin_type_for(entity_type: entity_type_for(data)),
        country: "US"
      )
    end

    # Populates what Tax::Form#import_taxbandits_data would otherwise have
    # derived from a TaxBandits sync, and marks the form completed directly:
    # these forms are already complete the moment TaxBandits accepts them, and
    # nothing will ever sync them afterwards.
    def complete_form!(form, data)
      entity_type = entity_type_for(data)

      form.update!(
        form_type: :W9,
        entity_type:,
        tin_type: Tax::IdentificationNumber::Hasher.tin_type_for(entity_type:),
        tin_hash: compute_tin_hash(data),
        address_line1: data[:address1],
        address_city: data[:city],
        address_state: data[:state],
        address_postal_code: data[:zip_code],
        address_country: "US",
        aasm_state: "completed",
        completed_at: Time.current
      )
    end

    def build_payload(form, data)
      {
        "FormType"      => "W9",
        "IsTinMatching" => false,
        "PayeeRef"      => form.public_id,
        "PdfUrl"        => "https://user-cdn.hackclub-assets.com/01a0e971-5fe0-7d34-b37f-cada21c0944d/Untitled%20document.pdf",
        "FormW9"        => {
          "FirstNm"                  => data[:first_name],
          "Line1Nm"                  => [data[:first_name], data[:middle_name], data[:last_name], data[:suffix]].compact.join(" "),
          "MiddleNm"                 => data[:middle_name],
          "LastNm"                   => data[:last_name],
          "Suffix"                   => data[:suffix],
          "TINType"                  => data[:tin_type],
          "TIN"                      => data[:tin],
          "Address"                  => {
            "Address1" => data[:address1],
            "City"     => data[:city],
            "State"    => data[:state],
            "ZipCd"    => data[:zip_code]
          },
          "FederalTaxClassification" => data[:federal_tax_classification]
        }
      }
    end

    # Associates the form with a legal entity by email, same as before:
    # SSNs go on the user's personal legal entity; EINs create (or reuse) a
    # business/corporation legal entity. Returns false when the user already
    # has an ambiguous set of business legal entities and this form is left
    # for manual review instead.
    def assign_legal_entity!(form, data)
      user = User.find_or_create_by!(email: data[:email])
      entity_type = entity_type_for(data)

      if entity_type == :person
        form.update!(legal_entity: user.personal_legal_entity)
        return true
      end

      existing_business_les = user.legal_entities.where.not(entity_type: :person).to_a

      if existing_business_les.empty?
        new_le = LegalEntity.create!(name: data[:first_name], entity_type:, users: [user])
        form.update!(legal_entity: new_le)
        return true
      end

      puts "  ! #{user.email} already has #{existing_business_les.size} business legal entit#{existing_business_les.size == 1 ? "y" : "ies"}:"
      existing_business_les.each_with_index { |le, i| puts "    #{i + 1}. #{le.name} (#{le.entity_type})" }
      print("  Enter a number to assign this form to that legal entity, or press Enter to leave for manual review: ")

      input = $stdin.gets.to_s.strip
      selected = existing_business_les[input.to_i - 1] if input.present?

      if selected
        form.update!(legal_entity: selected)
        true
      else
        puts "  Leaving this form for manual legal entity assignment."
        false
      end
    end

  end
end
