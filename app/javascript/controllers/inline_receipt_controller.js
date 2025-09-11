import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ["list", "fileInput", "clearButton", "bin", "receiptsInput"]
  static outlets = ["receipt-select"]

  binOpen = false

  receiptSelectOutletConnected(outlet) {
    outlet.render()
  }

  addFile() {
    const files = this.fileInputTarget.files;
    const newFile = files[files.length - 1]

    const html = `<li>${newFile.name}</li>`
    this.listTarget.innerHTML += html;
    this.clearButtonTarget.classList.remove("hidden")
  }

  addReceipt() {
    const selectedReceipt = this.binTarget.querySelector("select").value;

    const binElement = document.getElementById(`modal_receipt_${selectedReceipt}`);
    binElement.remove()

    const receipts = this.receiptsInputTarget.value.split(",")
    receipts.push(selectedReceipt)
    this.receiptsInputTarget.value = receipts.filter(r => r !== "").join(",")
   
    const html = `<li><turbo-frame id="receipt_item_${selectedReceipt}" src="/receipts/receipt_item?id=${selectedReceipt}"></turbo-frame></li>`
    this.listTarget.innerHTML += html;
    this.clearButtonTarget.classList.remove("hidden")

    this.receiptSelectOutlet.render()
  }

  clear() {
    this.fileInputTarget.value = "";
    this.receiptsInputTarget.value = ""
    this.receipts = []

    this.listTarget.innerHTML = "";
    this.clearButtonTarget.classList.add("hidden")

    const binFrame = this.binTarget.querySelector("turbo-frame")
    binFrame.reload();

    this.receiptSelectOutlet.render()
  }

  toggleBin(event) {
    event.preventDefault();

    if (this.binOpen) {
      this.binTarget.classList.add("hidden")
    } else {
      this.binTarget.classList.remove("hidden")
    }

    this.binOpen = !this.binOpen
  }
}