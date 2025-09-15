/* global getCookie, BK */
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

    let preview;
    if (newFile.type.startsWith("image")) {
      preview = URL.createObjectURL(newFile)
    }

    this.appendItem(newFile.name, preview)
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

    this.appendItem(metadata.name, metadata.preview)

    this.receiptSelectOutlet.render()

    if (this.hasExtractionOutlet) {
      this.extractionOutlet.pasteData(metadata)
    }
  }

  appendItem(name, image) {
    const itemElement = document.createElement("div")

    let imageUrl = image;
    if (!imageUrl) {
      const theme = getCookie('theme') || BK.resolveSystemTheme()
      imageUrl = `https://icons.hackclub.com/api/icons/${theme === "light" ? "black" : "white"}/payment-docs`
    }

    const imageElement = document.createElement("img")
    imageElement.src = imageUrl
    imageElement.alt = image ? `Receipt preview for "${name}"` : "Receipt icon"
    itemElement.appendChild(imageElement)

    const nameElement = document.createElement("p")
    nameElement.innerText = name
    itemElement.appendChild(nameElement)

    this.listTarget.appendChild(itemElement)
    this.clearButtonTarget.classList.remove('hidden')
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
