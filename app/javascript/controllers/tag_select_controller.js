import { Controller } from '@hotwired/stimulus'

// Client-side tag picker: the chosen tags render both as removable badges and as
// the hidden inputs the form submits. Markup comes from <template>s in the view
// so the icons stay in ERB.
export default class extends Controller {
  static targets = [
    'badges',
    'inputs',
    'query',
    'badgeTemplate',
    'inputTemplate',
    'create',
    'createLabel',
  ]
  static values = { tags: Array, createUrl: String }

  connect() {
    this.render()
  }

  add(event) {
    const tag = JSON.parse(event.currentTarget.dataset.tag)

    if (!this.tagsValue.some(chosen => chosen.id === tag.id)) {
      this.tagsValue = [...this.tagsValue, tag]
    }

    this.queryTarget.value = ''
    this.render()
  }

  remove(event) {
    const id = Number(event.currentTarget.dataset.tagId)

    this.tagsValue = this.tagsValue.filter(tag => tag.id !== id)
    this.render()
  }

  render() {
    this.badgesTarget.replaceChildren()
    this.inputsTarget.replaceChildren()

    this.tagsValue.forEach(tag => {
      const badge = this.badgeTemplateTarget.content.cloneNode(true)
      badge.querySelector('[data-tag-select-name]').textContent = tag.name
      badge.querySelector('button').dataset.tagId = tag.id
      this.badgesTarget.append(badge)

      const input = this.inputTemplateTarget.content.cloneNode(true)
      input.querySelector('input').value = tag.id
      this.inputsTarget.append(input)
    })

    this.renderCreateLink()
  }

  // The menu is cloned when it opens, so there can be more than one of these.
  renderCreateLink() {
    const query = this.queryTarget.value

    this.createTargets.forEach(link => {
      link.style.display = query.length > 0 ? '' : 'none'
      link.href = `${this.createUrlValue}?name=${encodeURIComponent(query)}`
    })
    this.createLabelTargets.forEach(label => (label.textContent = query))
  }
}
