export default ({ payment_recipient, editing }) => ({
  payment_recipient,
  editing: editing || false,
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
