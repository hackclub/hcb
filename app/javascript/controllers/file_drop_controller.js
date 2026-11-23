import { Controller } from '@hotwired/stimulus'
import submitForm from '../common/submitForm'
import { appsignal } from '../appsignal'

let dropzone

function extractId(dataTransfer) {
  let receiptId

  try {
    const html = dataTransfer.getData('text/html')

    const parser = new DOMParser()
    const doc = parser.parseFromString(html, 'text/html')
    const imgTag = doc.querySelector('img')

    receiptId = imgTag.getAttribute('data-receipt-id')
  } catch (err) {
    console.error(err)
  }

  if (!receiptId) {
    try {
      const uri = dataTransfer.getData('text/uri-list')
      const { pathname } = new URL(uri)

      const linkElement = document.querySelector(
        `a[href~="${pathname}"]:has(img)`
      )
      const imageElement = linkElement.querySelector('img')

      receiptId = imageElement.getAttribute('data-receipt-id')
    } catch (err) {
      console.error(err)
      appsignal.sendError(err)
    }
  }

  return receiptId
}

export default class extends Controller {
  static targets = [
    'fileInput',
    'dropzone',
    'form',
    'uploadMethod',
    'sizeError',
  ]
  static values = {
    title: { type: String, default: 'Drop to add a receipt' },
    linking: { type: Boolean, default: false },
    globalPaste: { type: Boolean, default: false },
    receiptable: String,
    modal: String,
    maxBytes: Number,
  }

  initialize() {
    // Explanation: https://stackoverflow.com/a/21002544/10987085
    this.counter = 0

    this.submitting = false

    const element = this.globalPasteValue
      ? document.body
      : this.hasFormTarget
        ? this.formTarget
        : this.element

    element.addEventListener('paste', e => {
      e.dataTransfer = e.clipboardData
      this.drop(e)
    })
  }

  dragover(e) {
    e.preventDefault()
  }

  async drop(e) {
    if (!e.clipboardData) e.preventDefault()

    this.counter = 0
    this.hideDropzone()

    // Another zone's drop (a transaction's row on a page that takes drops
    // anywhere in the window) is that zone's to handle.
    if (!e.clipboardData && this.inAnotherZone(e)) return

    if (this.linkingValue) {
      const receiptId = extractId(e.dataTransfer)

      // "Ledger::Item:123": the type is namespaced, so split on the last colon
      const separator = this.receiptableValue.lastIndexOf(':')
      const receiptableType = this.receiptableValue.slice(0, separator)
      const receiptableId = this.receiptableValue.slice(separator + 1)
      const linkPath = this.modalValue

      if (receiptId && receiptableType && receiptableId) {
        return submitForm(linkPath, {
          receipt_id: receiptId,
          receiptable_type: receiptableType,
          receiptable_id: receiptableId,
          show_link: true,
          show_receipt_button: true,
        })
      }
    }

    // A row that already has its receipt has no upload form left
    if (!this.hasFileInputTarget) return

    this.fileInputTarget.files = e.dataTransfer.files
    this.fileInputTarget.dispatchEvent(new Event('change'))
    if (!this.fileInputTarget.files.length) return

    if (
      this.hasUploadMethodTarget &&
      !this.submitting &&
      !this.uploadMethodTarget.value.endsWith('_drag_and_drop')
    ) {
      // Append `_drag_and_drop` to the upload method
      this.uploadMethodTarget.value += '_drag_and_drop'
    }

    if (this.hasFormTarget) {
      this.formTarget.requestSubmit()
    } else {
      this.element.requestSubmit()
    }

    this.submitting = true

    if (e.clipboardData && this.dropzoneTarget.contains(e.target))
      e.stopImmediatePropagation()

    if (
      this.hasUploadMethodTarget &&
      this.uploadMethodTarget.value.endsWith('_drag_and_drop')
    ) {
      this.uploadMethodTarget.value = this.uploadMethodTarget.value.slice(
        0,
        -'_drag_and_drop'.length
      )
    }

    this.submitting = false
  }

  // Runs before form#submit so an oversized file is never direct-uploaded.
  checkSize(e) {
    if (!this.hasSizeErrorTarget) return
    const files = [...this.fileInputTarget.files]
    const tooBig = files.filter(file => file.size > this.maxBytesValue)
    this.sizeErrorTarget.hidden = !tooBig.length
    if (!tooBig.length) return

    const names = tooBig.map(file => file.name).join(', ')
    const limit = `${Math.round(this.maxBytesValue / 1024 / 1024)} MB`
    // The whole selection is dropped, so say so when other files were picked too
    const several = files.length > 1 ? ', so nothing was uploaded' : ''
    this.sizeErrorTarget.textContent = `${names} ${tooBig.length > 1 ? 'are' : 'is'} over ${limit}${several}. Upload a smaller file.`
    this.fileInputTarget.value = ''
    e.stopImmediatePropagation()
  }

  dragenter(e) {
    // Leave the highlight to the zone the file is over
    if (this.inAnotherZone(e)) {
      this.hideDropzone()
    } else {
      this.showDropzone()
    }
    this.counter++
  }

  dragleave() {
    this.counter--
    if (this.counter == 0) {
      this.hideDropzone()
    }
  }

  /* Utilities */

  inAnotherZone(e) {
    const zone = e.target.closest?.('[data-controller~="file-drop"]')
    return Boolean(zone) && zone !== this.element
  }

  showDropzone() {
    if (this.hasDropzoneTarget) {
      this.dropzoneTarget.classList.add('dropzone')
      return
    }

    if (!dropzone) {
      dropzone = document.createElement('div')
      dropzone.classList.add('file-dropzone')

      const title = document.createElement('h1')
      title.innerText = this.titleValue
      dropzone.appendChild(title)

      document.body.appendChild(dropzone)
      document.body.style.overflow = 'hidden'

      // Explanation: https://stackoverflow.com/a/24195487/10987085
      window.getComputedStyle(dropzone).opacity

      dropzone.classList.add('visible')
    }
  }

  hideDropzone() {
    if (this.hasDropzoneTarget) {
      this.dropzoneTarget.classList.remove('dropzone')
      return
    }

    if (dropzone) {
      dropzone.remove()
      dropzone = undefined
      document.body.style.overflow = 'auto'
    }
  }
}
