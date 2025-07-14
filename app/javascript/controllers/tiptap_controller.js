import { Controller } from '@hotwired/stimulus'
import { debounce } from 'lodash/function'
import { Editor, Node, mergeAttributes } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'
import Underline from '@tiptap/extension-underline'
import Placeholder from '@tiptap/extension-placeholder'
import Link from '@tiptap/extension-link'
import Image from '@tiptap/extension-image'

const DonationGoalNode = Node.create({
  name: 'donationGoal',
  group: 'block',
  priority: 2000,
  renderHTML({ HTMLAttributes }) {
    return [
      'div',
      mergeAttributes(HTMLAttributes, {
        class:
          'donationGoal relative card shadow-none border flex flex-col py-2 my-2',
      }),
      [
        'p',
        { class: 'text-center italic' },
        'Your progress towards your goal will display here',
      ],
      [
        'div',
        { class: 'bg-gray-200 dark:bg-neutral-700 rounded-full w-full' },
        [
          'div',
          {
            class:
              'h-full bg-primary rounded w-1/2 flex items-center justify-center',
          },
          ['p', { class: 'text-sm text-black p-[1px] my-0' }, '50%'],
        ],
      ],
    ]
  },
  parseHTML() {
    return [
      {
        tag: 'div',
        getAttrs: node => node.classList.contains('donationGoal') && null,
      },
    ]
  },
  addCommands() {
    return {
      addDonationGoal:
        () =>
        ({ commands }) => {
          return commands.insertContent({ type: this.name })
        },
    }
  },
})

const HcbCodeNode = Node.create({
  name: 'hcbCode',
  group: 'block',
  priority: 2000,
  addAttributes() {
    return {
      code: {},
    }
  },
  renderHTML({ HTMLAttributes }) {
    return [
      'div',
      mergeAttributes(HTMLAttributes, {
        class:
          'hcbCode relative card shadow-none border flex flex-col py-2 my-2',
      }),
      [
        'p',
        { class: 'italic text-center' },
        `Your transaction (${HTMLAttributes.code}) will appear here.`,
      ],
    ]
  },
  parseHTML() {
    return [
      {
        tag: 'div',
        getAttrs: node => node.classList.contains('hcbCode') && null,
      },
    ]
  },
  addCommands() {
    return {
      addHcbCode:
        code =>
        ({ commands }) => {
          return commands.insertContent({
            type: this.name,
            attrs: { code },
          })
        },
    }
  },
})

const DonationSummaryNode = Node.create({
  name: 'donationSummary',
  group: 'block',
  priority: 2000,
  renderHTML({ HTMLAttributes }) {
    return [
      'div',
      mergeAttributes(HTMLAttributes, {
        class:
          'donationSummary relative card shadow-none border flex flex-col py-2 my-2',
      }),
      [
        'p',
        { class: 'italic text-center' },
        'A donation summary for the last month will appear here.',
      ],
    ]
  },
  parseHTML() {
    return [
      {
        tag: 'div',
        getAttrs: node => node.classList.contains('donationSummary') && null,
      },
    ]
  },
  addCommands() {
    return {
      addDonationSummary:
        () =>
        ({ commands }) => {
          return commands.insertContent({ type: this.name })
        },
    }
  },
})

export default class extends Controller {
  static targets = ['editor', 'form', 'contentInput', 'autosaveInput']
  static values = { content: String, event: String }

  editor = null

  connect() {
    const debouncedSubmit = debounce(this.submit.bind(this), 1000, {
      leading: true,
    })

    this.editor = new Editor({
      element: this.editorTarget,
      extensions: [
        StarterKit.configure({
          heading: {
            levels: [1, 2, 3],
          },
        }),
        Underline,
        Placeholder.configure({
          placeholder: 'Write a message to your followers...',
        }),
        Link,
        Image.configure({
          HTMLAttributes: {
            class: 'max-w-full',
          },
        }),
        DonationGoalNode,
        HcbCodeNode,
        DonationSummaryNode,
      ],
      editorProps: {
        attributes: {
          class: 'outline-none',
        },
      },
      content: this.hasContentValue
        ? JSON.parse(this.contentValue)
        : {
            type: 'doc',
            content: [
              {
                type: 'paragraph',
              },
            ],
          },
      onUpdate: () => {
        if (this.hasContentValue) {
          debouncedSubmit(true)
        }
      },
    })
  }

  disconnect() {
    this.editor.destroy()
  }

  submit(autosave) {
    this.autosaveInputTarget.value = autosave === true ? 'true' : 'false'
    this.contentInputTarget.value = JSON.stringify(this.editor.getJSON())
    this.formTarget.requestSubmit()
  }

  bold() {
    this.editor.chain().focus().toggleBold().run()
  }

  italic() {
    this.editor.chain().focus().toggleItalic().run()
  }

  underline() {
    this.editor.chain().focus().toggleUnderline().run()
  }

  h1() {
    this.editor.chain().focus().toggleHeading({ level: 1 }).run()
  }

  h2() {
    this.editor.chain().focus().toggleHeading({ level: 2 }).run()
  }

  h3() {
    this.editor.chain().focus().toggleHeading({ level: 3 }).run()
  }

  strike() {
    this.editor.chain().focus().toggleStrike().run()
  }

  link() {
    const url = window.prompt('Link URL')

    if (url === null) {
      return
    }

    if (url === '') {
      this.editor.chain().focus().extendMarkRange('link').unsetLink().run()
    } else {
      this.editor
        .chain()
        .focus()
        .extendMarkRange('link')
        .setLink({ href: url })
        .run()
    }
  }

  code() {
    this.editor.chain().focus().toggleCode().run()
  }

  codeBlock() {
    this.editor.chain().focus().toggleCodeBlock().run()
  }

  bulletList() {
    this.editor.chain().focus().toggleBulletList().run()
  }

  orderedList() {
    this.editor.chain().focus().toggleOrderedList().run()
  }

  blockQuote() {
    this.editor.chain().focus().toggleBlockquote().run()
  }

  image() {
    const url = window.prompt('Image URL')

    if (url === null || url === '') {
      return
    }

    this.editor.chain().focus().setImage({ src: url }).run()
  }

  donationGoal() {
    this.editor.chain().focus().addDonationGoal().run()
  }

  hcbCode() {
    const url = window.prompt('Transaction URL')

    if (url === null || url === '') {
      return
    }

    const code = url.split('/').at(-1)

    this.editor.chain().focus().addHcbCode(code).run()
  }

  donationSummary() {
    this.editor.chain().focus().addDonationSummary().run()
  }
}
