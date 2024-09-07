import { Controller } from '@hotwired/stimulus'
import csrf from '../common/csrf'

export default class extends Controller {
  static targets = ['transaction', 'tagger']
  static values = { selected: Array }

  select(event) {
    const target = event.currentTarget
    if ((event.metaKey || event.ctrlKey) && !event?.target?.href) {
      this.toggle(target)
      this.updateTaggerVisbility()
    }
  }

  toggle(target) {
    this.toggleHcbCode(document.getElementById(target.dataset.transaction))
  }

  toggleHcbCode(target) {
    let selected = this.selectedValue.slice()
    if (!selected.includes(target.id)) {
      selected.push(target.id)
      target.classList.add('selected__transaction')
    } else {
      selected = selected.filter(x => x != target.id)
      target.classList.remove('selected__transaction')
    }
    this.selectedValue = selected
  }

  updateTaggerVisbility() {
    if (this.selectedValue.length == 0) {
      this.taggerTarget.classList.add('display-none')
    } else {
      this.taggerTarget.classList.remove('display-none')
    }
  }

  async addTag(event) {
    const target = event.currentTarget
    const tagId = target.dataset.tagId
    const selected = this.selectedValue.slice()
    await Promise.all(
      selected.map(async item => {
        const response = await fetch(`/hcb/${item}/toggle_tag/${tagId}`, {
          method: 'POST',
          headers: {
            'X-CSRF-Token': csrf(),
            Accept: 'text/vnd.turbo-stream.html',
          },
        })
        if (response.ok) {
          const text = await response.text()
          this.toggleHcbCode(document.getElementById(item))
          window.Turbo.renderStreamMessage(text)
        }
      })
    )
    this.updateTaggerVisbility()
  }
}
