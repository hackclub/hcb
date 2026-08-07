CREATE OR REPLACE FUNCTION hcb_code_type(hcb_code text) RETURNS text
  LANGUAGE SQL
  IMMUTABLE
  RETURNS NULL ON NULL INPUT
  RETURN CASE SPLIT_PART(hcb_code, '-', 2)
    WHEN '000' THEN 'unknown'
    WHEN '001' THEN 'unknown_temporary'
    WHEN '100' THEN 'invoice'
    WHEN '200' THEN 'donation'
    WHEN '201' THEN 'partner_donation'
    WHEN '300' THEN 'ach_transfer'
    WHEN '310' THEN 'wire'
    WHEN '350' THEN 'paypal_transfer'
    WHEN '360' THEN 'wise_transfer'
    WHEN '400' THEN 'check'
    WHEN '401' THEN 'increase_check'
    WHEN '402' THEN 'check_deposit'
    WHEN '500' THEN 'outgoing_disbursement'
    WHEN '550' THEN 'incoming_disbursement'
    WHEN '600' THEN 'stripe_card'
    WHEN '601' THEN 'stripe_force_capture'
    WHEN '610' THEN 'stripe_service_fee'
    WHEN '700' THEN 'bank_fee'
    WHEN '701' THEN 'incoming_bank_fee'
    WHEN '702' THEN 'fee_revenue'
    WHEN '710' THEN 'expense_payout'
    WHEN '712' THEN 'payout_holding'
    WHEN '900' THEN 'outgoing_fee_reimbursement'
  END
