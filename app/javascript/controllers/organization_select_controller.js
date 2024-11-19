import { Controller } from '@hotwired/stimulus'
import fuzzysort from 'fuzzysort'

export default class extends Controller {
  static targets = [
    'dropdown',
    'menu',
    'search',
    'organization',
    'wrapper',
    'field',
  ]
  static values = {
    state: Boolean,
  }

  connect() {
    const organizations = {}

    const ensure = async callback => {
      try {
        await scheduler.yield()
        return callback()
      } catch {
        return callback()
      }
    }

    const open = () => {
      // eslint-disable-next-line no-undef
      $(this.menuTarget).slideDown()
      this.searchTarget.style.display = 'block'
      this.dropdownTarget.style.display = 'none'
      this.searchTarget.select()
    }

    const close = () => {
      // eslint-disable-next-line no-undef
      $(this.menuTarget).slideUp()
      this.searchTarget.style.display = 'none'
      this.dropdownTarget.style.display = 'flex'
    }

    const filter = async () => {
      const text = this.searchTarget.value

      const result = fuzzysort.go(
        this.searchTarget.value,
        Object.values(organizations),
        {
          keys: ['name', 'id'],
          all: true,
          threshold: -500000,
        }
      )

      firstOrganization = result[0]?.obj

      const shown = result.map(r => r.obj.organization)
      const hidden = this.organizationTargets.filter(el => !shown.includes(el))

      if (!ensure(() => text == this.searchTarget.value)) return

      for (const element of shown) {
        element.parentElement.appendChild(element)
        element.style.display = 'block'
        if (!ensure(() => text == this.searchTarget.value)) return
      }

      for (const element of hidden) {
        element.style.display = 'none'
        if (!ensure(() => text == this.searchTarget.value)) return
      }
    }

    for (const organization of this.organizationTargets) {
      const { name, id, fee } = organization.dataset
      const button = organization.children[0]
      const select = () => {
        const oldFieldValue =
          organizations[this.dropdownTarget.children[1].value]
        if (oldFieldValue) {
          Object.assign(oldFieldValue.button.style, {
            backgroundColor: 'unset',
            color: 'unset',
          })
          oldFieldValue.button.children[1].style.color = ''
        }

        Object.assign(button.style, {
          backgroundColor: 'var(--info)',
          color: 'white',
        })
        button.children[1].style.color = 'white'

        const fieldValue = this.dropdownTarget.children[1]
        fieldValue.innerText = name
        fieldValue.value = id
        fieldValue.dataset.fee = fee

        this.dropdownTarget.value = id
        this.dropdownTarget.dispatchEvent(new CustomEvent('feechange'))
        close()
      }

      organizations[id] = {
        name,
        id,
        organization,
        button,
        select,
        fee,
        visible: true,
      }

      // Select the organization when clicked
      button.onclick = e => {
        e.preventDefault()
        select()
      }
    }

    let firstOrganization = organizations[Object.keys(organizations)[0]]

    // Open the dropdown when activated by keyboard
    this.dropdownTarget.onkeypress = ({ key }) => {
      if (key === 'Enter' || key === ' ') {
        open()
        return false
      }
    }

    // Open the dropdown when clicked
    this.dropdownTarget.onmousedown = e => e.preventDefault()
    this.dropdownTarget.onclick = open

    // Close dropdown when clicking outside
    window.addEventListener('click', ({ target }) => {
      if (
        !this.wrapperTarget.contains(target) &&
        !this.dropdownTarget.contains(target)
      )
        close()
    })

    // Select first organization when pressing enter on search
    this.searchTarget.onkeypress = ({ key }) => {
      if (key === 'Enter') {
        firstOrganization?.select?.()
        this.dropdownTarget.focus()
        return false
      }
    }

    // Close dropdown when pressing escape
    this.searchTarget.onkeydown = ({ key }) => {
      if (key === 'Escape') close()
      this.dropdownTarget.focus()
    }

    const debounce = (callback, waitTime) => {
      let timer
      return (...args) => {
        clearTimeout(timer)
        timer = setTimeout(() => {
          callback(...args)
        }, waitTime)
      }
    }

    // Filter organizations when searching
    this.searchTarget.oninput = debounce(filter, 150)
  }
}
