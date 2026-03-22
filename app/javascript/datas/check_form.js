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
          document.getElementById('increase_check_recipient_email').value =
            this.payment_recipient.email
          document.getElementById('increase_check_address_line1').value =
            this.payment_recipient.address_line1
          document.getElementById('increase_check_address_line2').value =
            this.payment_recipient.address_line2
          document.getElementById('increase_check_address_city').value =
            this.payment_recipient.address_city
          document.getElementById('increase_check_address_state').value =
            this.payment_recipient.address_state
          document.getElementById('increase_check_address_zip').value =
            this.payment_recipient.address_zip
          document.getElementById('increase_check_address_line1').focus()
        })
      }
    })
  },
})
