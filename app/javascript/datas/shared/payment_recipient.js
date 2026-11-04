// Shared by the ACH, wire, and check transfer forms. The CSP build cannot
// resolve `JSON` from a directive expression, so parsing happens here and the
// views pass the raw `data-recipient` string in.
//
// These are plain methods rather than getters on purpose: the forms spread this
// object into their own, and spreading would invoke a getter instead of
// carrying it over.
export default {
  select_recipient(recipient) {
    this.payment_recipient = JSON.parse(recipient)
  },

  recipient_debug_info(recipient) {
    return 'Debug info:\n\n' + JSON.stringify(recipient || {}, null, 2)
  },
}
