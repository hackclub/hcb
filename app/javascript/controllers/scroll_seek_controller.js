import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['section', 'tab']

  connect() {
    this.observer = new IntersectionObserver(
      entries => this.handleIntersection(entries),
      {
        threshold: 0,
        rootMargin: '-100px 0px -66% 0px',
      }
    )

    this.sectionTargets.forEach(section => {
      const heading = section.querySelector('h3')
      if (heading) {
        this.observer.observe(heading)
      }

      section.addEventListener('focusin', () => this.handleFocusIn(section))
    })

    this.tabTargets.forEach((tab, index) => {
      tab.addEventListener('click', () => this.handleTabClick(index))
    })

    window.addEventListener('scroll', () => this.handleScroll())
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
    window.removeEventListener('scroll', () => this.handleScroll())
  }

  handleTabClick(index) {
    this.activateTab(index)
    this.sectionTargets[index]?.scrollIntoView({
      block: 'start',
      inline: 'start',
    })
    window.scrollBy(0, -100)
  }

  handleScroll() {
    if (window.scrollY <= 10) {
      this.activateTab(0)
    } else if (
      window.innerHeight + window.scrollY >=
      document.documentElement.scrollHeight - 10
    ) {
      this.activateTab(this.sectionTargets.length - 1)
    }
  }

  handleIntersection(entries) {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const section = entry.target.closest(
          '[data-scroll-seek-target="section"]'
        )
        const index = this.sectionTargets.indexOf(section)
        this.activateTab(index)
      }
    })
  }

  handleFocusIn(section) {
    const index = this.sectionTargets.indexOf(section)
    this.activateTab(index)
  }

  activateTab(index) {
    this.tabTargets.forEach(tab => tab.classList.remove('active'))

    if (this.tabTargets[index]) {
      this.tabTargets[index].classList.add('active')
    }

    if (window.innerWidth < 640 && this.tabTargets[index]) {
      if (index === 0) {
        this.tabTargets[index].parentElement.parentElement.scrollTo({
          left: 0,
          behavior: 'smooth',
        })
        return
      } else if (index === this.tabTargets.length - 1) {
        this.tabTargets[index].parentElement.parentElement.scrollTo({
          left: this.tabTargets[index].parentElement.scrollWidth,
          behavior: 'smooth',
        })
        return
      } else {
        this.tabTargets[index].scrollIntoView({
          block: 'start',
          inline: 'nearest',
          behavior: 'smooth',
        })
      }
    }
  }
}
