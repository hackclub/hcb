import { Node } from '@tiptap/core'

export const DonationGoalNode = Node.create({
  name: 'Announcement::Block::DonationGoal',
  atom: true,
  group: 'block',
  priority: 2000,
  addAttributes() {
    return {
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
      addDonationGoal:
        attrs =>
        ({ commands }) => {
          return commands.insertContent({ type: this.name, attrs })
        },
    }
  },
})
