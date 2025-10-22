import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = []
  static values = {
    key: String,
    progress: Number,
  }

  static WALKTHROUGHS = {
    donations: [
      {
        element: null,
        title: "Welcome to Donations",
        content: "HCB's donations feature provides a customizable donation page that can be shared online. Donors can choose one-time or recurring donations, and you can customize tiers & design.",
      },
      {
        element: null,
        title: "Share",
        content: "Customize donation page links, embed your form, generate QR codes, and share real-time donor graphs"
      },
      {
        element: null,
        title: "Customize your donation page",
        content: "You can display banners, create donation tiers, and set donation goals here"
      },
    ]
  }

  connect() {

  }

  save() {

  }
}
