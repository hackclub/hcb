import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="qr-code"
// Handles switching the icon shown in the center of the donation QR code
// and downloading the active QR code as an image.
export default class extends Controller {
  static targets = ['downloadButton']

  change(event) {
    const id = event.params.id
    const next = this.element.querySelector(`#qrCode--${id}`)
    if (!next) return

    const active = this.element.querySelector('qr-code.\\!block')
    if (active) active.classList.remove('!block')
    next.classList.add('!block')

    if (this.hasDownloadButtonTarget) {
      this.downloadButtonTarget.innerText = 'Download'
    }
  }

  download() {
    const button = this.hasDownloadButtonTarget ? this.downloadButtonTarget : null
    const active = this.element.querySelector('qr-code.\\!block')
    if (!active || typeof window.html2canvas !== 'function') return

    if (button) button.innerText = 'Downloading...'

    window
      .html2canvas(active, { scale: 4, backgroundColor: null, useCORS: true })
      .then(canvas => {
        const downloadLink = document.createElement('a')
        downloadLink.href = canvas.toDataURL('image/png')
        downloadLink.download = 'qr_code.png'
        downloadLink.click()
        if (button) button.innerText = 'Download'
      })
      .catch(error => {
        console.error(error)
        if (button) button.innerText = 'Try Again'
      })
  }
}
