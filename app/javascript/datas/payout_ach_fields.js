// The ACH fields render masked (••••1234) until the user focuses one. Focusing
// clears them for editing; blurring both while they are still empty puts the
// masked values back. When the stored numbers failed validation they are shown
// unmasked and there is nothing to restore, so the restore values are passed in
// separately rather than derived from the initial ones.
export default ({
  routingNumber,
  accountNumber,
  editing,
  restoreRoutingNumber,
  restoreAccountNumber,
}) => ({
  routingNumber,
  accountNumber,
  editing,

  toggle() {
    if (!this.editing) {
      this.routingNumber = ''
      this.accountNumber = ''
      this.editing = true
    } else if (this.routingNumber == '' && this.accountNumber == '') {
      this.editing = false
      this.routingNumber = restoreRoutingNumber
      this.accountNumber = restoreAccountNumber
    }
  },
})
