import { BaseRuleVisitor, ParserRule } from "@herb-tools/linter"

// A column with no visible heading still needs to say what it holds, as an
// ERB comment: <th><%# user avatar %></th>. An empty <th></th> leaves the next
// reader guessing which td it lines up with.
class Visitor extends BaseRuleVisitor {
  visitHTMLElementNode(node) {
    if (node.tag_name?.value?.toLowerCase() === "th") {
      const meaningful = (node.body ?? []).some(child => {
        if (child.type === "AST_HTML_TEXT_NODE") return child.content.trim() !== ""
        if (child.type === "AST_WHITESPACE_NODE") return false
        return true // ERB output, ERB comment, nested tags
      })
      if (!meaningful) {
        this.addOffense(
          "Empty `<th>`. Name the column in an ERB comment, e.g. `<th><%# actions menu %></th>`.",
          node.open_tag.location
        )
      }
    }
    super.visitHTMLElementNode(node)
  }
}

export default class TableHeaderHasContentRule extends ParserRule {
  static ruleName = "table-header-has-content"
  check(result, context) {
    const visitor = new Visitor(this.ruleName, context)
    visitor.visit(result.value)
    return visitor.offenses
  }
}
