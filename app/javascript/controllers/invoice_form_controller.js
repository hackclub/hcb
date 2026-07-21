import { Controller } from '@hotwired/stimulus'
import csrf from '../common/csrf'

export default class extends Controller {
  static targets = [
    'sponsorDropdownContainer',
    'sponsorDropdownTrigger',
    'sponsorDropdownMenu',
    'sponsorDropdownLabel',
    'sponsorOptionRow',
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

  dropdownOpen = false
  _selectedSponsorJson = null

  connect() {
    const hasSponsors = this.hasSponsorDropdownContainerTarget

    if (!hasSponsors) {
      this.continueButtonTarget.disabled = false
      this.showNewSponsorCard()
    }

    this.sponsorFormTarget.addEventListener(
      'change',
      this.validateForm.bind(this)
    )

    this._boundHandleDocumentClick = this.handleDocumentClick.bind(this)
    document.addEventListener('click', this._boundHandleDocumentClick)

    this.validateForm()
  }

  disconnect() {
    document.removeEventListener('click', this._boundHandleDocumentClick)
  }

  handleDocumentClick(event) {
    if (
      this.hasSponsorDropdownContainerTarget &&
      !this.sponsorDropdownContainerTarget.contains(event.target) &&
      this.dropdownOpen
    ) {
      this.closeSponsorDropdown()
    }
  }

  toggleSponsorDropdown(event) {
    event.stopPropagation()
    this.dropdownOpen ? this.closeSponsorDropdown() : this.openSponsorDropdown()
  }

  openSponsorDropdown() {
    this.dropdownOpen = true
    this.sponsorDropdownMenuTarget.classList.remove('hidden')
  }

  closeSponsorDropdown() {
    this.dropdownOpen = false
    this.sponsorDropdownMenuTarget.classList.add('hidden')
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

  chooseSponsorOption(event) {
    const button = event.currentTarget
    const value = button.dataset.value
    const name = button.dataset.name

    this.sponsorDropdownLabelTarget.innerHTML = name

    this.continueButtonTarget.disabled = false
    this.secondTabTarget.disabled = false

    if (value) {
      this._selectedSponsorJson = JSON.parse(button.dataset.json)
      this.showSponsorCard()
    } else {
      this._selectedSponsorJson = null
      this.showNewSponsorCard()
    }

    this.closeSponsorDropdown()
    this.validateForm()
  }

  async deleteSponsor(event) {
    event.stopPropagation()

    const button = event.currentTarget
    const sponsorId = button.dataset.sponsorId
    const sponsorName = button.dataset.sponsorName
    const sponsorPath = button.dataset.sponsorPath

    if (
      !confirm(
        `Delete ${sponsorName}? This will also delete all of their invoices.`
      )
    )
      return

    try {
      const response = await fetch(sponsorPath, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': csrf(),
          Accept: 'application/json',
        },
      })

      if (!response.ok) {
        alert('Failed to delete sponsor.')
        return
      }

      const row = document.getElementById(`sponsor-option-${sponsorId}`)
      if (row) row.remove()

      if (this._selectedSponsorJson?.id == sponsorId) {
        this._selectedSponsorJson = null
        this.sponsorDropdownLabelTarget.textContent = 'Select…'
        this.showNewSponsorCard()
      }

      if (this.sponsorOptionRowTargets.length === 0) {
        const divider = this.sponsorDropdownMenuTarget.querySelector('hr')
        if (divider) divider.remove()
        this.closeSponsorDropdown()
        this.showNewSponsorCard()
        this.sponsorDropdownContainerTarget.classList.add('hidden')
      }
    } catch (e) {
      console.error('Failed to delete sponsor', e)
      alert('Failed to delete sponsor.')
    }
  }

  setValues() {
    const sponsor = this._selectedSponsorJson
    if (!sponsor) return

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
    const warning = document.getElementById('sponsor-warning')
    if (warning) warning.hidden = true
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
    const warning = document.getElementById('sponsor-warning')
    if (warning) warning.hidden = false
    this.setValues()
  }
}
