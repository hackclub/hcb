import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['input', 'preview', 'clear']
  static values = { placeholder: 'Attach file' }

  truncateMiddle(text, maxLen = 20) {
    if (text.length <= maxLen) return text
    const half = Math.floor(maxLen / 2)
    return text.slice(0, half) + '...' + text.slice(-half)
  }

  static cloudIcon = `<svg width="32" height="32" class="-ml-1 mr-1" viewBox="0 0 32 32" fill="currentColor" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" clip-rule="evenodd" d="M17 7C19.4194 7 21.4374 8.71837 21.9002 11.0012C24.1171 10.9472 26 12.7809 26 15C26 17.2091 24.2091 19 22 19C21.4477 19 21 18.5523 21 18C21 17.4477 21.4477 17 22 17C23.1046 17 24 16.1046 24 15C24 13.8954 23.1046 13 22 13C21.7137 13 21.4301 13.0367 21.1499 13.0962C20.6068 13.2113 20 12.5551 20 12C20 10.3432 18.6569 9 17 9C15.2449 9 14.1626 10.151 13.7245 11.534C13.5099 12.2114 12.7936 12.6737 12.1486 12.3754C11.6937 12.1651 11.282 12 11 12C10.4477 12 10 12.4477 10 13C10.254 14.0159 9.48563 15 8.43845 15H8C7.44772 15 7 15.4477 7 16C7 16.5523 7.44772 17 8 17H10C10.5523 17 11 17.4477 11 18C11 18.5523 10.5523 19 10 19H8C6.34314 19 5 17.6569 5 16C5 14.3431 6.34314 13 8 13C8 11.3431 9.34314 10 11 10C11.4651 10 11.9055 10.1058 12.2983 10.2947C12.9955 8.37292 14.8374 7 17 7ZM19.7071 19.2929L16.7071 16.2929C16.3166 15.9024 15.6834 15.9024 15.2929 16.2929L12.2929 19.2929C11.9024 19.6834 11.9024 20.3166 12.2929 20.7071C12.6834 21.0976 13.3166 21.0976 13.7071 20.7071L15 19.4142V25C15 25.5523 15.4477 26 16 26C16.5523 26 17 25.5523 17 25V19.4142L18.2929 20.7071C18.6834 21.0976 19.3166 21.0976 19.7071 20.7071C20.0976 20.3166 20.0976 19.6834 19.7071 19.2929Z" /></svg>`
  static xIcon = `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" fill="currentColor" fill-rule="evenodd" stroke-linejoin="round" stroke-miterlimit="1.414" aria-label="view-close" clip-rule="evenodd" preserveAspectRatio="xMidYMid meet" viewBox="0 0 32 32"><g><path d="M11.121,9.707c-0.39,-0.391 -1.024,-0.391 -1.414,0c-0.391,0.39 -0.391,1.024 0,1.414l4.95,4.95l-4.95,4.95c-0.391,0.39 -0.391,1.023 0,1.414c0.39,0.39 1.024,0.39 1.414,0l4.95,-4.95l4.95,4.95c0.39,0.39 1.023,0.39 1.414,0c0.39,-0.391 0.39,-1.024 0,-1.414l-4.95,-4.95l4.95,-4.95c0.39,-0.39 0.39,-1.024 0,-1.414c-0.391,-0.391 -1.024,-0.391 -1.414,0l-4.95,4.95l-4.95,-4.95Z"/></g></svg>`

  resetPreview() {
    this.previewTarget.innerHTML = `${this.cloudIcon} ${this.placeholderValue}`
  }

  connect() {
    this.resetPreview()
    this.previewTarget.classList.add('tooltipped')
    this.previewTarget.onclick = () => this.inputTarget.click()
    this.inputTarget.onchange = () => this.render()
    window.addEventListener('turbo:morph', this.connect.bind(this))
  }

  render() {
    const input = this.inputTarget
    const fileName = input.files.length > 0 ? input.files[0].name : ''

    if (!fileName) return
    this.previewTarget.setAttribute('aria-label', fileName)
    this.previewTarget.innerHTML = `<img class="-ml-0.5 mr-2 w-4" src="https://cdn.jsdelivr.net/npm/file-icon-vectors@1.0.0/dist/icons/classic/${fileName.split('.').pop()}.svg" /> ${this.truncateMiddle(fileName)}`
    this.clearTarget.style.display = 'flex'
    this.previewTarget.classList.add('active')
    this.clearTarget.innerHTML = this.xIcon
    this.clearTarget.type = 'button'
    this.clearTarget.addEventListener('click', () => {
      input.value = ''
      this.clearTarget.innerHTML = ''
      this.clearTarget.style.display = 'none'
      this.previewTarget.classList.remove('active')
      this.previewTarget.classList.remove('tooltipped')
      this.resetPreview()
    })
  }
}
