import { Controller } from '@hotwired/stimulus'

// Picks the scoped tags a new sub-organization starts with. The menu holding
// the options is cloned each time it opens, so there can be more than one
// "create this tag" link to keep in sync with the query.
export default class extends Controller {
  static targets = ['query', 'tags', 'tagTemplate', 'createLink']
  static values = { createUrl: String }

  add({ params: { tag } }) {
    if (!this.findTag(tag.id)) {
      const badge =
        this.tagTemplateTarget.content.firstElementChild.cloneNode(true)
      badge.dataset.tagId = tag.id
      badge.querySelector('input').value = tag.id
      badge.querySelector('span').textContent = tag.name
      badge.querySelector('button').dataset.scopedTagPickerIdParam = tag.id
      this.tagsTarget.append(badge)
    }

    // dispatch `input` so the option filter and create link reset too
    this.queryTarget.value = ''
    this.queryTarget.dispatchEvent(new Event('input'))
  }

  remove({ params: { id } }) {
    this.findTag(id)?.remove()
  }

  update() {
    const query = this.queryTarget.value
    const url = new URL(this.createUrlValue)
    url.searchParams.set('name', query)

    this.createLinkTargets.forEach(link => {
      link.hidden = query.length == 0
      link.href = url
      link.querySelector('span').textContent = query
    })
  }

  findTag(id) {
    return this.tagsTarget.querySelector(`[data-tag-id="${id}"]`)
  }
}
