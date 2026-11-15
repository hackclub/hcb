import ReactRailsUJS from 'react_ujs'

export function mountReactNode(dom, id) {
  const observer = new MutationObserver((mutationsList, observer) => {
    for (const mutation of mutationsList) {
      if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
        mutation.addedNodes.forEach(node => {
          if (node == dom || (id && node.id === id)) {
            ReactRailsUJS.mountComponents()
            observer.disconnect()
          }
        })
      }
    }
  })

  observer.observe(document, {
    attributes: true,
    childList: true,
    subtree: true,
  })
}
