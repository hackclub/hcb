# frozen_string_literal: true

module OneTimeJobs
  class ImportTax1099W9Forms < ApplicationJob
    def perform(csv_path)
      csv_content = File.read(csv_path)
      rows = csv_content.split("\n")[1..]

      failed_rows = []
      imported_count = 0
      manual_review_count = 0

      # Row schema:
      # Payer Name, Payer TIN, Payee First Name, Payee Middle Name, Payee Last Name, Payee Suffix,
      # EIN/SSN, W9 Requested Date, W9 Received Date, Email Address, Mail Status (opened, delivered, rejected, etc),
      # Business Type, Filer Type, Address, City, State, Zip Code, Country, W9 Request, W9 Count,
      # W9 Completed Date, W9 Cancel Date
      rows.each_with_index do |row, i|
        # Importing the form
        form = Tax::Form.create!

        is_ssn = row[6].count("-") == 2
        payload = {
          "FormType"      => "W9",
          "IsTinMatching" => false,
          "PayeeRef"      => form.public_id,
          "FormW9"        => {
            "FirstNm"                  => row[2],
            "MiddleNm"                 => row[3],
            "LastNm"                   => row[4],
            "Suffix"                   => row[5],
            "TINType"                  => is_ssn ? "SSN" : "EIN",
            "TIN"                      => row[6],
            "Address"                  => {
              "Address1" => row[13],
              "City"     => row[14],
              "State"    => row[15],
              "ZipCd"    => row[16]
            },
            "FederalTaxClassification" => row[12]
          }
        }

        begin
          tb_response = TaxbanditsService.create_from_data(payload)
        rescue => e
          failed_rows.push(i + 1)
        end

        form.update!(external_service: :taxbandits, external_id: tb_response["SubmissionId"])

        # Associate with a LE if possible
        # If it's a business LE and the user already has a business LE,
        # we'll manually review the forms without an LE later
        user = User.find_or_create_by!(email: row[9])
        if is_ssn
          form.update!(legal_entity: user.personal_legal_entity)
        elsif user.legal_entities.where.not(entity_type: :personal).none?
          new_le = LegalEntity.create!(
            name: row[4],
            entity_type: row[12].include?("Corporation") ? :corporation : :business, # TODO: verify the possible values of this field
            users: [user]
          )

          form.update!(legal_entity: new_le)
        end
      end

      if failed_rows.any?
        print("Failed to import rows #{failed.map { |r| "##{r}" }.join(", ")}")
      end

      print("Successfully imported #{imported_count} forms")
      print("#{manual_review_count} forms need manual LE assignment")
    end

  end
end
