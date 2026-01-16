import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  connect() {
    this.render()
  }

  render() {
    const scrollY = window.scrollY
    const checkPreview = document.getElementById('check-preview-container')
    const tableOfContents = document.getElementById('table-of-contents')
    const contactInformation = document.getElementById('contact-information')

    if (!checkPreview || !tableOfContents || !contactInformation) {
      return
    }

    if (scrollY < 200) {
      const scale = 1 - scrollY / 400
      checkPreview.style.transform = `scale(${scale}) translateY(${scrollY / 2}px)`
      tableOfContents.style.top = `${445 - scrollY * 0.975}px`
      contactInformation.style.paddingTop = `${scrollY / 4}px`
      checkPreview.parentElement.style.width = `${100 - scrollY / 4}%`
    } else {
      checkPreview.style.transform = 'scale(0.5) translateY(100px)'
      tableOfContents.style.top = `250px`
      contactInformation.style.paddingTop = `50px`
      checkPreview.parentElement.style.width = `0%`
    }

    checkPreview.parentElement.parentElement.style.pointerEvents =
      scrollY === 0 ? 'auto' : 'none'
  }
}
