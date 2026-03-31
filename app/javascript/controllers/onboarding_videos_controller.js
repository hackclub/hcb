/* global YT */

import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['player']
  static values = { buttonId: String }

  connect() {
    this.startedMap = new Map()
    this.players = []

    if (!window.YT || !window.YT.Player) {
      window.onYouTubeIframeAPIReady = () => this.initializePlayers()
      const tag = document.createElement('script')
      tag.src = 'https://www.youtube.com/iframe_api'
      document.head.appendChild(tag)
    } else {
      this.initializePlayers()
    }
  }

  initializePlayers() {
    this.playerTargets.forEach((el, index) => {
      const videoId = el.dataset.videoId

      const player = new YT.Player(el, {
        videoId: videoId,
        height: '100%',
        events: {
          onStateChange: event => this.handleStateChange(index, event),
        },
      })

      this.players.push(player)
      this.startedMap.set(index, false)
    })
  }

  handleStateChange(index, event) {
    console.log('state')
    if (event.data === YT.PlayerState.PLAYING) {
      console.log('PLAY!')
      this.startedMap.set(index, true)
      this.checkAllStarted()
    }
  }

  checkAllStarted() {
    const allStarted = Array.from(this.startedMap.values()).every(v => v)

    if (allStarted) {
      document.getElementById(this.buttonIdValue).disabled = false
    }
  }
}
