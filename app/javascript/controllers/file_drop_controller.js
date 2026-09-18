import { Controller } from '@hotwired/stimulus'
import submitForm from '../common/submitForm'
import { appsignal } from '../appsignal'

let dropzone

// The id of the receipt a drag started on, when the drag started on a receipt
// that's already in HCB (the receipt bin, a suggested pairing, a "Select from
// Receipt Bin" modal). Reading it at the source is exact; `extractId` below has
// to guess from the serialized drag payload, and browsers disagree about what
// they put in there.
let draggedReceiptId = null

document.addEventListener('dragstart', e => {
  draggedReceiptId =
    e.target?.closest?.('[data-receipt-id]')?.getAttribute('data-receipt-id') ||
    null
})

// Cleared once the drag is over, after every dropzone handler has had its turn:
// a drop bubbles to the document last, and a drag that ends any other way (the
// pointer leaves the window, Escape) still fires `dragend` on the source.
document.addEventListener('dragend', () => {
  draggedReceiptId = null
})

document.addEventListener('drop', () => {
  draggedReceiptId = null
})

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
  static targets = ['fileInput', 'dropzone', 'form', 'uploadMethod']
  static values = {
    title: { type: String, default: 'Drop to add a receipt' },
    linking: { type: Boolean, default: false },
    globalPaste: { type: Boolean, default: false },
    receiptable: String,
    modal: String,
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

    // A paste has no drag of its own, so a receipt dragged earlier in the page
    // must not be mistaken for what was pasted.
    const draggedReceipt = e.clipboardData ? null : draggedReceiptId

    if (this.linkingValue) {
      const receiptId = draggedReceipt || extractId(e.dataTransfer)

      const [receiptableType, receiptableId] = this.receiptableValue.split(':')
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

    // The drag started on a receipt HCB already has. Browsers hand the image
    // file over alongside the markup, so falling through to the upload branch
    // would attach a second copy of the receipt here and leave the original
    // sitting in the receipt bin. There is nothing to upload.
    if (draggedReceipt) return

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

  dragenter() {
    if (this.counter == 0) {
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
