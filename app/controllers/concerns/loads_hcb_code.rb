# frozen_string_literal: true

module LoadsHcbCode
  extend ActiveSupport::Concern

  private

  # Finds an HcbCode by hcb_code string or by primary key.
  # This supports both "HCB-xxx-123" style codes and numeric IDs.
  def find_hcb_code(param = params[:id])
    HcbCode.find_by(hcb_code: param) || HcbCode.find(param)
  end
end
