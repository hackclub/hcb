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
  }

  continue() {
    const inputs = this.sponsorFormTarget.querySelectorAll('input')
    if ([...inputs].every(input => input.checkValidity())) {
      document.getElementById('invoice').disabled = false
      document.getElementById('invoice').click()
    } else {
      this.showNewSponsorCard()
      ;[...inputs].reverse().forEach(input => input.reportValidity())
    }
  }

  selectSponsor() {
    this.continueButtonTarget.disabled = false

    const { value } = this.selectSponsorTarget
    if (parseInt(value)) this.showSponsorCard()
    else this.showNewSponsorCard()
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

  showNewSponsorCard() {
    this.sponsorCollapsibleTarget.open = true
    this.sponsorCollapsibleTarget.setAttribute('class', '')
    this.sponsorPreviewTarget.classList.add('!hidden')
    this.sponsorFormTarget.setAttribute('class', '')
    this.clearValues()
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
