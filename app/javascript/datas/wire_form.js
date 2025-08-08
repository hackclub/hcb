export default ({ payment_recipient, editing, country }) => ({
  payment_recipient,
  country,
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
          document.getElementById('wire_recipient_email').value =
            this.payment_recipient.email
          document.getElementById('wire_address_line1').value =
            this.payment_recipient.address_line1
          document.getElementById('wire_address_line2').value =
            this.payment_recipient.address_line2
          document.getElementById('wire_address_city').value =
            this.payment_recipient.address_city
          document.getElementById('wire_address_state').value =
            this.payment_recipient.address_state
          document.getElementById('wire_recipient_country').value =
            this.payment_recipient.recipient_country
          document.getElementById('wire_address_postal_code').value =
            this.payment_recipient.address_postal_code
          document.getElementById('wire_bic_code').value =
            this.payment_recipient.bic_code
          document.getElementById('wire_address_line1').focus()
        })
      }
    })
  },
})
