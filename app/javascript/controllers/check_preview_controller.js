import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  connect() {
    this.render()

    window.addEventListener('resize', this.render)
  }

  scrollToTop() {
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  render() {
    const scrollY = window.scrollY
    const checkPreview = document.getElementById('check-preview-container')
    const tableOfContents = document.getElementById('table-of-contents')
    const contactInformation = document.getElementById('contact-information')

    if (!checkPreview || !tableOfContents || !contactInformation) return

    checkPreview.classList[scrollY === 0 ? 'remove' : 'add']('cursor-pointer')
    checkPreview.onclick = () => this.scrollToTop()

    if (scrollY < 200) {
      const tableWidth = tableOfContents.getBoundingClientRect().width
      const targetScale = tableWidth / 720

      const scale = 1 + (targetScale - 1) * (scrollY / 200)

      checkPreview.style.transform = `scale(${scale}) translateY(${scrollY / 2}px)`
      contactInformation.style.paddingTop = `${scrollY / 4}px`
      checkPreview.parentElement.style.width = `${100 - scrollY / 4}%`
    } else {
      const tableWidth = tableOfContents.getBoundingClientRect().width
      const targetScale = tableWidth / 720

      checkPreview.style.transform = `scale(${targetScale}) translateY(100px)`
      contactInformation.style.paddingTop = `50px`
      checkPreview.parentElement.style.width = `0%`
    }

    tableOfContents.style.top = `${checkPreview.getBoundingClientRect().top + checkPreview.getBoundingClientRect().height + 16}px`

    checkPreview.parentElement.parentElement.style.pointerEvents =
      scrollY === 0 ? 'auto' : 'none'
    checkPreview.querySelector('div').style.pointerEvents =
      scrollY === 0 ? 'auto' : 'none'
  }
}
