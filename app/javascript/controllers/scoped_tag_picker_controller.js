import { Controller } from '@hotwired/stimulus'

// Picks the scoped tags a new sub-organization starts with. Each picked tag is
// a badge holding a hidden `scoped_tags[]` input, and typing a name that isn't
// listed offers a link to create that tag.
//
// The menu controller shows a clone of the tag menu, so everything in the menu
// is reached through targets, which include the clone.
export default class extends Controller {
  static targets = ['query', 'picked', 'badge', 'createLink', 'createName']
  static values = { createUrl: String }

  // Clicked on a tag in the menu.
  add({ currentTarget }) {
    const { scopedTag: id, name } =
      currentTarget.closest('[data-scoped-tag]').dataset

    if (!this.badgeFor(id)) {
      const badge = this.badgeTarget.content.firstElementChild.cloneNode(true)
      badge.dataset.scopedTagPickerId = id
      badge.querySelector('input').value = id
      badge.querySelector('[data-name]').textContent = name
      badge.querySelector('button').dataset.scopedTagPickerIdParam = id
      this.pickedTarget.append(badge)
    }

    this.queryTarget.value = ''
    this.query()
  }

  // Clicked a picked tag's remove button, or deleted the tag from the menu.
  remove({ params: { id } }) {
    this.badgeFor(id)?.remove()
  }

  query() {
    const name = this.queryTarget.value
    const url = new URL(this.createUrlValue, window.location.href)
    url.searchParams.set('name', name)

    this.createLinkTargets.forEach(link => {
      link.hidden = name.length === 0
      link.href = url
    })
    this.createNameTargets.forEach(target => (target.textContent = name))
  }

  badgeFor(id) {
    return this.pickedTarget.querySelector(
      `[data-scoped-tag-picker-id="${CSS.escape(String(id))}"]`
    )
  }
}
