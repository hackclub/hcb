import { Controller } from '@hotwired/stimulus'
import { toPng } from 'html-to-image'

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
    const button = this.hasDownloadButtonTarget
      ? this.downloadButtonTarget
      : null
    const active = this.element.querySelector('qr-code.\\!block')
    if (!active) return

    if (button) button.innerText = 'Downloading...'

    toPng(active, { pixelRatio: 4, backgroundColor: null, cacheBust: true })
      .then(dataUrl => {
        const downloadLink = document.createElement('a')
        downloadLink.href = dataUrl
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
