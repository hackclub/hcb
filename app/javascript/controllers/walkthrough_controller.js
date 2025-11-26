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
        title: 'Welcome to Donations',
        content:
          "HCB's donations feature provides a customizable donation page that can be shared online. Donors can choose one-time or recurring donations, and you can customize tiers & design.",
      },
      {
        element: null,
        title: 'Share',
        content:
          'Customize donation page links, embed your form, generate QR codes, and share real-time donor graphs',
      },
      {
        element: null,
        title: 'Customize your donation page',
        content:
          'You can display banners, create donation tiers, and set donation goals here',
      },
    ],
    reimbursements: [
      {
        element: null,
        title: 'Welcome to Reimbursements',
        content:
          'Reimbursements are when you repay someone with funds from your HCB account. An example of this would be if you forgot your physical HCB card at home so you purchased something for your organization with your personal money, so you would pay yourself back with funds from your HCB account.',
      },
      {
        element: null,
        title: 'Create a Reimbursement',
        content:
          'To create a reimbursement, click the "New Reimbursement" button and fill out the required fields.',
      },
    ],
  }

  connect() {}

  save() {}
}
