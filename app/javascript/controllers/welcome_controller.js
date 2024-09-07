import { Controller } from '@hotwired/stimulus'
import { gsap } from 'gsap'
import csrf from '../common/csrf'

export default class extends Controller {
  static values = {
    organizerPosition: Number,
  }

  initialize() {
    this.shouldReload = false
  }

  connect() {
    document.body.style.overflow = 'hidden'
    this.tl = gsap.timeline({ delay: 0.5 })

    this.tl.fromTo(
      '.welcome__image',
      {
        opacity: 0,
        scale: 0.8,
        filter: 'blur(5px)',
      },
      {
        opacity: 1,
        scale: 1.2,
        filter: 'blur(0px)',

        duration: 1.5,
        ease: 'power2.out',
      }
    )

    this.tl
      .to('.welcome', {
        backgroundColor:
          document.documentElement.dataset.dark == 'true'
            ? 'rgba(23, 23, 29, 0.5)'
            : 'rgba(249, 250, 252, 0.5)',
        duration: 1.5,
      })
      .to(
        '.welcome',
        {
          backdropFilter: 'blur(10px)',
          duration: 0,
        },
        '<0.01' // Turn on backdrop filter only after the background starts transitioning. Weird Firefox bug.
      )

    this.tl.fromTo(
      '.welcome__content > *',
      { opacity: 0, y: 20 },
      {
        opacity: 1,
        y: 0,

        duration: 1.5,
        stagger: 0.3,
        ease: 'power2.out',
      },
      '<'
    )
    this.tl.to(
      '.welcome__image',
      {
        scale: 1,
        duration: 1.5,
        ease: 'power2.out',
      },
      '<'
    )
    this.tl.to(
      '.welcome__shine',
      {
        backgroundPosition: '50px 50px',
        duration: 1,
      },
      '<'
    )
    this.tl.to(
      '.welcome__shine_text',
      {
        backgroundPosition: '50px 50px',
        color: '#ec3750',
        duration: 1,
      },
      '<'
    )
    this.tl.to(
      '.welcome__shine_text_head',
      {
        opacity: 1,
        duration: 1,
      },
      '<'
    )

    this.hideTl = gsap.timeline({
      paused: true,
      onComplete: () => {
        document.body.style.overflow = 'auto'
        if (this.shouldReload) {
          location.replace(location.pathname) // TODO: remove
        }
      },
    })
    this.hideTl.fromTo(
      '.welcome__shine',
      { backgroundPosition: '-50px -50px' },
      { backgroundPosition: '50px 50px', duration: 1 }
    )
    this.hideTl.to(
      '.welcome',
      {
        autoAlpha: 0,
        duration: 1,
        ease: 'power2.inOut',
      },
      '<0.5'
    )
    this.hideTl.to(
      '.welcome__image, .welcome__content > *',
      {
        y: -20,
        ease: 'power2.inOut',
        duration: 1,
      },
      '<'
    )
  }

  async tour() {
    this.shouldReload = true

    this.hideTl.play()

    if (this.organizerPositionValue) {
      await fetch(
        `/organizer_positions/${this.organizerPositionValue}/mark_visited`,
        {
          method: 'POST',
          headers: {
            'X-CSRF-Token': csrf(),
            'Content-Type': 'application/json',
          },
          redirect: 'manual',
          body: JSON.stringify({ start_tour: true }),
        }
      )
    }
  }

  async dismiss(e) {
    e.preventDefault()

    this.hideTl.play()

    if (this.organizerPositionValue) {
      await fetch(
        `/organizer_positions/${this.organizerPositionValue}/mark_visited`,
        {
          method: 'POST',
          headers: {
            'X-CSRF-Token': csrf(),
          },
          redirect: 'manual',
        }
      )
    }
  }
}
