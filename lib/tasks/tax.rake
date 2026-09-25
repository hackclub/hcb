# frozen_string_literal: true

namespace :tax do
  # Reads STDIN so the export, which holds raw TINs, is never written to disk or storage.
  desc "Import Tax1099 W-9s and W-8s from a CSV on STDIN (a dry run unless COMMIT=1)"
  task import_tax1099: :environment do
    puts Tax::FormService::ImportTax1099.new(csv: $stdin.read, commit: ENV["COMMIT"] == "1", form_type: ENV["FORM_TYPE"]).run
  end
end
