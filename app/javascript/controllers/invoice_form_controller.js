import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'selectSponsor',
    'sponsorCollapsible',
    'sponsorForm',
    'sponsorPreview',
    'sponsorPreviewName',
    'sponsorPreviewEmail',
    'continueButton',
    'secondTab',
  ]

  static fields = [
    'name',
    'contact_email',
    'address_line1',
    'address_line2',
    'address_city',
    'address_state',
    'address_postal_code',
    'address_country',
    'id',
  ]

  connect() {
    if (this.selectSponsorTarget.disabled) {
      this.continueButtonTarget.disabled = false
      this.showNewSponsorCard()
    }

    this.sponsorFormTarget.addEventListener(
      'change',
      this.validateForm.bind(this)
    )

    this.validateForm()
  }

  validateForm() {
    const inputs = this.sponsorFormTarget.querySelectorAll('input, select')
    const isValid = [...inputs].every(input => input.checkValidity())
    this.continueButtonTarget.disabled = !isValid
    this.secondTabTarget.disabled = !isValid
  }

  continue() {
    const inputs = this.sponsorFormTarget.querySelectorAll('input, select')
    if ([...inputs].every(input => input.checkValidity())) {
      document.getElementById('invoice').disabled = false
      document.getElementById('invoice').click()
    } else {
      this.showNewSponsorCard(false)
      ;[...inputs].reverse().forEach(input => input.reportValidity())
    }
  }

  selectSponsor() {
    this.continueButtonTarget.disabled = false
    this.secondTabTarget.disabled = false

    const { value } = this.selectSponsorTarget
    if (parseInt(value)) this.showSponsorCard()
    else this.showNewSponsorCard()
    this.validateForm()
  }

  setValues() {
    let sponsor =
      this.selectSponsorTarget.options[this.selectSponsorTarget.selectedIndex]
        .dataset.json
    sponsor = JSON.parse(sponsor)

    this.sponsorPreviewNameTarget.innerText = sponsor.name || ''
    this.sponsorPreviewEmailTarget.innerText = sponsor.contact_email || ''

    this.constructor.fields.forEach(field => {
      const element = document.getElementById(
        `invoice_sponsor_attributes_${field}`
      )
      if (element) element.value = sponsor[field] || ''
    })
  }

  clearValues() {
    this.constructor.fields.forEach(field => {
      const element = document.getElementById(
        `invoice_sponsor_attributes_${field}`
      )
      if (element) element.value = ''
    })
  }

  showNewSponsorCard(clear = true) {
    this.sponsorCollapsibleTarget.open = true
    this.sponsorCollapsibleTarget.setAttribute('class', '')
    this.sponsorPreviewTarget.classList.add('!hidden')
    this.sponsorFormTarget.setAttribute('class', '')
    if (clear) this.clearValues()
  }

  showSponsorCard() {
    this.sponsorCollapsibleTarget.open = false
    this.sponsorCollapsibleTarget.setAttribute(
      'class',
      'border rounded-lg overflow-hidden'
    )
    this.sponsorPreviewTarget.classList.remove('!hidden')
    this.sponsorFormTarget.setAttribute('class', 'px-7 p-4 pt-0')
    this.setValues()
  }
}
