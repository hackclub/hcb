import { Node } from '@tiptap/core'
import ReactRailsUJS from 'react_ujs'

export const TopTagsNode = Node.create({
  name: 'topTags',
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

      const observer = new MutationObserver((mutationsList, observer) => {
        for (const mutation of mutationsList) {
          if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
            mutation.addedNodes.forEach(node => {
              if (node == dom) {
                ReactRailsUJS.mountComponents()
                observer.disconnect()
              }
            })
          }
        }
      })

      observer.observe(document, { attributes: true, childList: true, subtree: true })

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
