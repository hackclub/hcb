export default ({ payment_recipient, editing, validate_routing_number_url }) => ({
  payment_recipient,
  editing: editing || false,
  validateRoutingNumberUrl: validate_routing_number_url,
  routingNumberHint: '',
  routingNumberValid: false,
  async lookupBank(value) {
    if (!value) {
      this.routingNumberHint = ''
      return
    }
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    const { valid, hint } = await fetch(this.validateRoutingNumberUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': csrfToken },
      body: JSON.stringify({ value }),
    }).then(r => r.json()).catch(() => ({ valid: false, hint: '' }))

    this.routingNumberValid = valid
    this.routingNumberHint = hint || ''

    if (valid && hint) {
      const bankNameField = document.getElementById('ach_transfer_bank_name')
      if (bankNameField && !bankNameField.value) {
        bankNameField.value = hint
      }
    }
  },
  init() {
    this.$watch('payment_recipient', rec => {
      if (rec) {
        this.editing = false
        this.$refs.name_input.value = rec.name
      }
    })

    this.$watch('editing', (n, o) => {
      if (n == true && o == false) {
        this.$nextTick(() => {
          document.getElementById('ach_transfer_recipient_email').value =
            this.payment_recipient.email
          document.getElementById('ach_transfer_bank_name').value =
            this.payment_recipient.bank_name
          document.getElementById('ach_transfer_routing_number').value =
            this.payment_recipient.routing_number
          document.getElementById('ach_transfer_bank_name').focus()
        })
      }
    })
  },
})
