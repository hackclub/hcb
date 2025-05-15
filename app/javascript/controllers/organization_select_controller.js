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
    'other',
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

      const result = fuzzysort.go(this.searchTarget.value, orgValues, {
        keys: ['name', 'id', 'slug'],
        all: false,
        threshold: -500000,
        limit: 50,
      })

      const visible =
        result.length > 0
          ? result.map(r => r.obj)
          : this.searchTarget.value.length > 0
            ? []
            : orgValues
                .sort((a, b) => a.index - b.index)

                .slice(0, 50)

      firstOrganization = visible[0]

      const shownElements = visible.map(o => o.organization)

      if (this.hasOtherTarget && this.searchTarget.value.length > 0) {
        shownElements.push(this.otherTarget)

        if (shownElements.length == 1)
          firstOrganization = organizations['other']
        const { button } = organizations['other']

        const searchMatchesSelected =
          this.searchTarget.value == this.dropdownTarget.value

        Object.assign(
          button.style,
          searchMatchesSelected
            ? {
                backgroundColor: 'var(--info)',
                color: 'white',
              }
            : {
                backgroundColor: 'unset',
                color: 'unset',
              }
        )

        this.otherTarget.querySelector('.other-name').innerText =
          `Other (${this.searchTarget.value})`
      }

      const hiddenElements = this.allOrganizations.filter(
        el => !shownElements.includes(el)
      )

      for (const element of shownElements) {
        element.parentElement.appendChild(element)
        element.style.display = 'block'
      }

      for (const element of hiddenElements) {
        element.style.display = 'none'
      }
    }

    for (const organization of this.allOrganizations) {
      const { name, id, fee, index, slug } = organization.dataset
      const button = organization.children[0]

      const select = () => {
        const previouslySelected =
          organizations[this.dropdownTarget.children[1].value]
        if (previouslySelected) {
          Object.assign(previouslySelected.button.style, {
            backgroundColor: 'unset',
            color: 'unset',
          })
          previouslySelected.button.children[1].style.color = ''
        }

        Object.assign(button.style, {
          backgroundColor: 'var(--info)',
          color: 'white',
        })
        button.children[1].style.color = 'white'

        const fieldValue = this.dropdownTarget.children[1]
        fieldValue.innerText = button.children[0].innerText

        const newValue = id == 'other' ? this.searchTarget.value : id
        fieldValue.value = newValue
        fieldValue.dataset.fee = fee
        this.dropdownTarget.value = newValue
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
        slug,
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

  get allOrganizations() {
    if (this.hasOtherTarget) {
      return [...this.organizationTargets, this.otherTarget]
    }

    return this.organizationTargets
  }
}
