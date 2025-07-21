import { Node } from '@tiptap/core'

export const DonationSummaryNode = Node.create({
  name: 'donationSummary',
  atom: true,
  group: 'block',
  priority: 2000,
  addAttributes() {
    return {
      start_date: {},
      id: {},
      html: {},
    }
  },
  renderHTML({ HTMLAttributes }) {
    return ['node-view', HTMLAttributes]
  },
  addNodeView() {
    return ({ node }) => {
      const dom = document.createElement('div')
      dom.innerHTML = node.attrs.html

      return { dom }
    }
  },
  addCommands() {
    return {
      addDonationSummary:
        attrs =>
        ({ commands }) => {
          return commands.insertContent({ type: this.name, attrs })
        },
    }
  },
})
