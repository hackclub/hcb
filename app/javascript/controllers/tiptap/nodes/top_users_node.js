import { Node } from '@tiptap/core'
import { mountReactNode } from '../mount_react_node.js'

export const TopUsersNode = Node.create({
  name: 'Announcement::Block::TopUsers',
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

      mountReactNode(dom)

      return { dom }
    }
  },
  addCommands() {
    return {
      addTopUsers:
        attrs =>
        ({ commands }) => {
          return commands.insertContent({ type: this.name, attrs })
        },
    }
  },
})
