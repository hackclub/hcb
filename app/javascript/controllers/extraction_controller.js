import { Controller } from '@hotwired/stimulus'
import csrf from '../common/csrf'

export default class extends Controller {
  static targets = ['form']
  async upload(e) {
    const file = e.target.files[0]

    if (!file) return

    const formData = new FormData()
    formData.append('file', file)

    const response = await fetch('/extract/invoice', {
      method: 'POST',
      body: formData,
      headers: { 'X-CSRF-Token': csrf() },
    }).then(res => res.json())

    let empty = true

    Array.from(this.formTarget.elements).map(element => {
      if (
        element.dataset.extractionField &&
        Object.keys(response).includes(element.dataset.extractionField)
      ) {
        if (element.value != '') {
          empty = false
        }
      }
    })

    if (empty) {
      Array.from(this.formTarget.elements).map(element => {
        if (
          element.dataset.extractionField &&
          Object.keys(response).includes(element.dataset.extractionField)
        ) {
          element.value = response[element.dataset.extractionField]
        }
      })
    }
  }
}
