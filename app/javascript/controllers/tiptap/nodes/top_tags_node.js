import { Node } from '@tiptap/core'
import { mountReactNode } from '../mount_react_node.js'

export const TopTagsNode = Node.create({
  name: 'Announcement::Block::TopTags',
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
      addTopTags:
        attrs =>
        ({ commands }) => {
          return commands.insertContent({ type: this.name, attrs })
        },
    }
  },
})
