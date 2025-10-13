/* global Turbo */

import { Controller } from '@hotwired/stimulus'
import csrf from '../common/csrf'
import JSConfetti from 'js-confetti'

export default class extends Controller {
  static targets = ['form']
  async upload(e) {
    const file = e.target.files[0]

    if (!file) return

    const formData = new FormData()
    formData.append('file', file)

    document.querySelector('html').setAttribute('data-ai-loading', true)
    Turbo.navigator.delegate.adapter.showProgressBar()

    const response = await fetch('/extract/invoice', {
      method: 'POST',
      body: formData,
      headers: { 'X-CSRF-Token': csrf() },
    }).then(res => res.json())

    Turbo.navigator.delegate.adapter.progressBar.hide()
    document.querySelector('html').setAttribute('data-ai-loading', false)

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
          element.dispatchEvent(new Event('paste'))
        }
      })

      let dropzone = document.createElement('div')
      dropzone.classList.add('file-dropzone')
      dropzone.classList.add('data-extracted')

      const title = document.createElement('h1')
      title.innerText = '🧾 Successfully extracted!'
      dropzone.appendChild(title)

      document.body.appendChild(dropzone)
      document.body.style.overflow = 'hidden'

      // Explanation: https://stackoverflow.com/a/24195487/10987085
      window.getComputedStyle(dropzone).opacity

      dropzone.classList.add('visible')

      const jsConfetti = new JSConfetti()

      jsConfetti
        .addConfetti({
          emojis: '✨',
        })
        .then(() => {
          dropzone.remove()
          document.body.style.overflow = 'auto'
        })
    }
  }
}
