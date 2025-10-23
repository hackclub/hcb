import { Controller } from '@hotwired/stimulus'
import { encodeOPSaveRequest } from '@1password/save-button'

export default class extends Controller {
  click(e) {
    e.preventDefault()

    const dataset = this.element.dataset

    const saveRequest = {
      title: dataset.ccTitle,
      fields: [
        {
          autocomplete: 'cc-name',
          value: dataset.ccName,
        },
        {
          autocomplete: 'cc-number',
          value: dataset.ccNumber,
        },
        {
          autocomplete: 'cc-exp',
          value: dataset.ccExp, //yyyymm
        },
        {
          autocomplete: 'cc-csc',
          value: dataset.ccCsc,
        },
        {
          autocomplete: 'cc-type',
          value: dataset.ccType,
        },
        {
          autocomplete: 'street-address',
          value: dataset.ccStreetAddress,
        },
        {
          autocomplete: 'address-level2',
          value: dataset.ccAddressCity,
        },
        {
          autocomplete: 'address-level1',
          value: dataset.ccAddressState,
        },
        {
          autocomplete: 'postal-code',
          value: dataset.ccAddressPostalCode,
        },
        {
          autocomplete: 'country',
          value: dataset.ccAddressCountry,
        },
      ],
      notes: `HCB card for ${dataset.organizationName}`,
    }
    const encodedSaveRequest = encodeOPSaveRequest(saveRequest)

    document
      .querySelector('onepassword-save-button')
      .shadowRoot.querySelector('button[data-onepassword-save-button]')
      .setAttribute('value', encodedSaveRequest)
  }
}
