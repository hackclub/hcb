import { Controller } from '@hotwired/stimulus'

// example implementation: data-controller="timestamp" data-timestamp-time-value="<%= activity.created_at.to_i * 1000 %>"
// to_i gets you seconds since epoch! JS needs milliseconds.

export default class extends Controller {
  static values = {
    time: Number,
  }

  connect() {
    this.interval = setInterval(() => {
      this.element.innerText = DateHelper.time_ago_in_words(this.timeValue)
    }, 60000)
  }

  disconnect() {
    if (this.interval) clearInterval(this.interval)
  }
}

// sourced from https://gist.github.com/deadkarma/1989808
// thank you @deadkarma!

let DateHelper = {
  // Takes a timestamp and converts it to a relative time
  // DateHelper.time_ago_in_words(1331079503000)
  time_ago_in_words: function (from) {
    return this.distance_of_time_in_words(new Date(), from)
  },

  distance_of_time_in_words: function (to, from) {
    var distance_in_seconds = (to - from) / 1000
    var distance_in_minutes = Math.floor(distance_in_seconds / 60)
    var tense = distance_in_seconds < 0 ? ' from now' : ' ago'
    distance_in_minutes = Math.abs(distance_in_minutes)
    if (distance_in_minutes == 0) {
      return 'less than a minute' + tense
    }
    if (distance_in_minutes == 1) {
      return 'a minute' + tense
    }
    if (distance_in_minutes < 45) {
      return distance_in_minutes + ' minutes' + tense
    }
    if (distance_in_minutes < 90) {
      return 'about an hour' + tense
    }
    if (distance_in_minutes < 1440) {
      return 'about ' + Math.floor(distance_in_minutes / 60) + ' hours' + tense
    }
    if (distance_in_minutes < 2880) {
      return 'a day' + tense
    }
    if (distance_in_minutes < 43200) {
      return Math.floor(distance_in_minutes / 1440) + ' days' + tense
    }
    if (distance_in_minutes < 86400) {
      return 'about a month' + tense
    }
    if (distance_in_minutes < 525960) {
      return Math.floor(distance_in_minutes / 43200) + ' months' + tense
    }
    if (distance_in_minutes < 1051199) {
      return 'about a year' + tense
    }

    return 'over ' + Math.floor(distance_in_minutes / 525960) + ' years'
  },
}
