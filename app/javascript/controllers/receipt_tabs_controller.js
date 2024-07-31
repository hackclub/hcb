import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['previewLabel', 'detailsLabel', 'preview', 'details']

  selectPreview() {
    this.previewTarget.style.display = 'block'
    this.detailsTarget.style.display = 'none'
    this.previewLabelTarget.parentElement.classList.add('active')
    this.detailsLabelTarget.parentElement.classList.remove('active')
  }

  selectDetails() {
    this.detailsTarget.style.display = 'block'
    this.previewTarget.style.display = 'none'
    this.detailsLabelTarget.parentElement.classList.add('active')
    this.previewLabelTarget.parentElement.classList.remove('active')
  }
}
