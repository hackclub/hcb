import { Controller } from '@hotwired/stimulus'
import csrf from '../common/csrf'

export default class extends Controller {
  static targets = [
    'list',
    'fileInput',
    'clearButton',
    'bin',
    'receiptsInputContainer',
  ]
  static outlets = ['receipt-select', 'extraction']

  binOpen = false

  receiptSelectOutletConnected(outlet) {
    outlet.render()
  }

  addFile() {
    const files = this.fileInputTarget.files
    const newFile = files[files.length - 1]

    const html = `<li>${newFile.name}</li>`
    this.listTarget.innerHTML += html
    this.clearButtonTarget.classList.remove('hidden')
  }

  async addReceipt() {
    const selectedReceiptId = this.binTarget.querySelector('select').value

    const binElement = document.getElementById(
      `modal_receipt_${selectedReceiptId}`
    )
    binElement.remove()

    const newInput = document.createElement('input')
    newInput.type = 'hidden'
    newInput.value = selectedReceiptId
    newInput.name = 'receipts[]'
    this.receiptsInputContainerTarget.appendChild(newInput)

    const metadata = await fetch(`/receipts/${selectedReceiptId}/metadata`, {
      headers: { 'X-CSRF-Token': csrf() },
    }).then(res => res.json())

    const html = `<li>${metadata.name}</li>`
    this.listTarget.innerHTML += html
    this.clearButtonTarget.classList.remove('hidden')

    this.receiptSelectOutlet.render()

    if (this.hasExtractionOutlet) {
      this.extractionOutlet.pasteData(metadata)
    }
  }

  clear() {
    this.fileInputTarget.value = ''
    this.receiptsInputContainerTarget.innerHTML = ''
    this.receipts = []

    this.listTarget.innerHTML = ''
    this.clearButtonTarget.classList.add('hidden')

    const binFrame = this.binTarget.querySelector('turbo-frame')
    binFrame.reload()

    this.receiptSelectOutlet.render()
  }

  toggleBin(event) {
    event.preventDefault()

    if (this.binOpen) {
      this.binTarget.classList.add('hidden')
    } else {
      this.binTarget.classList.remove('hidden')
    }

    this.binOpen = !this.binOpen
  }
}
