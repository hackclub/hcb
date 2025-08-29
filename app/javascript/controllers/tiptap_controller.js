/* global Turbo */

import { Controller } from '@hotwired/stimulus'
import { debounce } from 'lodash/function'
import { Editor } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'
import Underline from '@tiptap/extension-underline'
import Placeholder from '@tiptap/extension-placeholder'
import Link from '@tiptap/extension-link'
import Image from '@tiptap/extension-image'
import { mountReactNode } from './tiptap/mount_react_node'

import csrf from '../common/csrf'
import { DonationGoalNode } from './tiptap/nodes/donation_goal_node'
import { HcbCodeNode } from './tiptap/nodes/hcb_code_node'
import { DonationSummaryNode } from './tiptap/nodes/donation_summary_node'
import { TopMerchantsNode } from './tiptap/nodes/top_merchants_node'
import { TopCategoriesNode } from './tiptap/nodes/top_categories_node'
import { TopTagsNode } from './tiptap/nodes/top_tags_node'
import { TopUsersNode } from './tiptap/nodes/top_users_node'

export default class extends Controller {
  static targets = ['editor', 'form', 'contentInput', 'autosaveInput']
  static values = {
    content: String,
    announcementId: Number,
    autosave: Boolean,
    followers: Number,
    published: Boolean,
  }

  editor = null

  connect() {
    const debouncedSubmit = debounce(this.submit.bind(this), 1000, {
      leading: true,
    })

    let content
    if (this.hasContentValue) {
      content = JSON.parse(this.contentValue)
    } else {
      content = {
        type: 'doc',
        content: [
          {
            type: 'paragraph',
          },
        ],
      }
    }

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
          placeholder: 'Write a message...',
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
        TopMerchantsNode,
        TopCategoriesNode,
        TopTagsNode,
        TopUsersNode,
      ],
      editorProps: {
        attributes: {
          class: 'outline-none',
        },
      },
      content,
      onUpdate: () => {
        if (this.autosaveValue) {
          debouncedSubmit(true)
        }
      },
    })
  }

  disconnect() {
    this.editor.destroy()
  }

  submit(autosave) {
    if (autosave !== true && !this.publishedValue) {
      const data = new FormData(this.formTarget)
      const draft = data.get('announcement[draft]')

      if (draft === 'false') {
        let confirmed = confirm(
          `Are you sure you would like to publish this announcement and notify ${this.followersValue} follower${this.followersValue === 1 ? '' : 's'}?`
        )

        if (!confirmed) return
      }
    }

    this.autosaveInputTarget.value = autosave === true ? 'true' : 'false'
    this.contentInputTarget.value = JSON.stringify(this.editor.getJSON())
    this.formTarget.requestSubmit()
  }

  focus() {
    this.editor.chain().focus().run()
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

  async block(type, parameters, blockId) {
    let result
    if (blockId) {
      result = await this.editBlock(blockId, parameters)
    } else {
      result = await this.createBlock(type, parameters)
    }

    if (result !== null && 'errors' in result) {
      return result['errors']
    } else if (!blockId) {
      this.editor.chain().focus().insertContent({ type, attrs: result }).run()
    }

    return null
  }

  async donationGoal() {
    const attrs = await this.createBlock('Announcement::Block::DonationGoal')

    if (attrs !== null) {
      this.editor.chain().focus().addDonationGoal(attrs).run()
    }
  }

  async createBlock(type, parameters) {
    const res = await fetch('/announcements/blocks', {
      method: 'POST',
      body: JSON.stringify({
        type,
        announcement_id: this.announcementIdValue,
        parameters: JSON.stringify(parameters || {}),
      }),
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrf(),
      },
    }).then(r => r.json())

    return res
  }

  async editBlock(id, parameters) {
    const res = await fetch(`/announcements/blocks/${id}`, {
      method: 'PATCH',
      body: JSON.stringify({
        parameters: JSON.stringify(parameters || {}),
      }),
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrf(),
      },
    }).then(res => {
      if (res.status === 400) {
        return res.json()
      } else {
        return res.text().then(html => {
          Turbo.renderStreamMessage(html)
          mountReactNode(null, `block_${id}`)
          return null
        })
      }
    })

    return res
  }
}
