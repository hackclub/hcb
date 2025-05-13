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
      const orgValues = Object.values(organizations)

      const start = performance.now()
      const result = fuzzysort.go(this.searchTarget.value, orgValues, {
        keys: ['name', 'id'],
        all: false,
        threshold: -500000,
        limit: 50,
      })
      const end = performance.now()

      firstOrganization = result[0]?.obj

      const shown =
        result.length > 0
          ? result.map(r => r.obj.organization)
          : orgValues
              .sort((a, b) => a.index - b.index)
              .map(o => o.organization)
              .slice(0, 50)
      const hidden = this.organizationTargets.filter(el => !shown.includes(el))
      console.log('Search took', end - start, 'ms')
      const renderStart = performance.now()

      for (const element of shown) {
        ;(async () => {
          element.parentElement.appendChild(element)
          element.style.display = 'block'
        })()
      }

      for (const element of hidden) {
        ;(async () => {
          element.style.display = 'none'
        })()
      }

      const renderEnd = performance.now()

      console.log('Render took', renderEnd - renderStart, 'ms')
    }

    for (const organization of this.organizationTargets) {
      const { name, id, fee, index } = organization.dataset
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
        index,
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

    if (this.dropdownTarget.children[1].value) {
      const selected = organizations[this.dropdownTarget.children[1].value]
      if (selected) {
        selected.select()
      }
    }

    // Filter organizations when searching
    this.searchTarget.oninput = debounce(filter, 100)
  }
}
