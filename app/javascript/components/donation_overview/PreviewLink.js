import React from 'react'
import PropTypes from 'prop-types'
import Icon from '@hackclub/icons'

class PreviewLink extends React.Component {
  constructor(props) {
    super(props)

    this.state = {
      amount: null,
      message: null,
      monthly: false,
      goods: false,
      copy: null,
    }

    this.handleChange = this.handleChange.bind(this)
    this.handleCopy = this.handleCopy.bind(this)
  }

  handleCopy(e) {
    e.preventDefault()
    let copyText = this.inputField

    copyText.select()
    copyText.setSelectionRange(0, copyText.value.length)
    navigator.clipboard.writeText(copyText.value)
    this.setState({ copy: true })
    // after 3 seconds, go back to default
    setTimeout(() => {
      this.setState({ copy: null })
    }, 3 * 1000)
  }

  handleChange(e) {
    let field = e.target.name.replace('prefill-', '')
    if (e.target.value == '') {
      this.setState({ [field]: null })
    } else {
      switch (field) {
        case 'amount': {
          let amount = parseFloat(e.target.value) * 100
          if (Number.isFinite(amount) && amount > 0) {
            this.setState({ amount })
          }
          break
        }
        case 'message':
          this.setState({ message: e.target.value })
          break
        case 'monthly':
          this.setState({ monthly: e.target.checked })
          break
        case 'goods':
          this.setState({ goods: e.target.checked })
          break
      }
    }
  }

  render() {
    const { path } = this.props
    let url = new URL(path)

    const showSubtitle =
      this.state.amount != null ||
      this.state.message != null ||
      this.state.monthly ||
      this.state.goods

    if (this.state.monthly) url.searchParams.set('monthly', this.state.monthly)

    if (this.state.message) url.searchParams.set('message', this.state.message)

    if (this.state.goods) url.searchParams.set('goods', this.state.goods)

    if (this.state.amount) url.searchParams.set('amount', this.state.amount)

    return (
      <div className="flex flex-col gap-3">
        <div className="flex-1">
          <h4 className="my-3">
            {showSubtitle ? 'Prefilled donation' : 'Donation'} link
          </h4>
          <div className="flex items-center input pr-2 w-full max-w-full mb-1">
            <input
              value={url}
              readOnly={true}
              name="prefill-url"
              type="text"
              className="!border-0 p-0 min-h-0 flex-1 !shadow-none select-all"
              style={{ maxWidth: '100%' }}
              ref={c => (this.inputField = c)}
            />
            <button className="pop ml-auto" onClick={this.handleCopy}>
              <Icon glyph="copy" size={24} />
            </button>
          </div>
        </div>
        <div className="flex-1">
          <hr className="my-3" />
          <h4 className="mt-5 mb-3">Customize</h4>
          <div className="flex gap-2 flex-col sm:flex-row">
            <div className="flex-1">
              <label
                htmlFor="prefill-amount"
                className="mb1"
                style={{ fontWeight: 600 }}
              >
                Amount
              </label>
              <div className="flex items-center input px-3 gap-1">
                <span className="bold muted" style={{ width: '1rem' }}>
                  $
                </span>
                <input
                  placeholder="500.00"
                  step="0.01"
                  min="0.01"
                  type="number"
                  className="!border-0 p-0 flex-1 !shadow-none"
                  style={{ minHeight: 0, padding: 0 }}
                  name="prefill-amount"
                  onChange={this.handleChange}
                />
              </div>
            </div>
            <div style={{ flex: 2 }}>
              <label
                htmlFor="prefill-message"
                className="mb1"
                style={{ fontWeight: 600 }}
              >
                Message
              </label>
              <div className="field">
                <div className="flex items-center">
                  <input
                    placeholder="Optional"
                    type="text"
                    name="prefill-message"
                    onChange={this.handleChange}
                  />
                </div>
              </div>
            </div>
          </div>

          <div className="flex items-center mb-2">
            <span style={{ fontWeight: 600, marginRight: '0.5rem' }}>
              Charge monthly?
            </span>
            <label
              className="field--checkbox--switch ml-auto"
              style={{ flexShrink: 0 }}
            >
              <input
                id="prefill-monthly"
                type="checkbox"
                name="prefill-monthly"
                onChange={this.handleChange}
                checked={this.state.monthly}
                className="switch"
              />
              <span className="slider"></span>
            </label>
          </div>
          <div className="flex items-center mb-2">
            <span style={{ fontWeight: 600, marginRight: '0.5rem' }}>
              Mark as &quot;receiving goods for this donation?&quot;
              <a
                className="tooltipped tooltipped--w link--ignore inline-flex align-middle"
                aria-label="Per IRS guidelines, for a contribution to be tax-deductible in the US, you agree that no goods or services will be provided in return for this gift. Please leave this box blank if making a tax-deductible donation that you will receive no goods or services for."
              >
                <Icon glyph="info" size={16} className="ml-1" />
              </a>
            </span>
            <label
              className="field--checkbox--switch ml-auto"
              style={{ flexShrink: 0 }}
            >
              <input
                id="prefill-goods"
                type="checkbox"
                name="prefill-goods"
                onChange={this.handleChange}
                checked={this.state.goods}
                className="switch"
              />
              <span className="slider"></span>
            </label>
          </div>
        </div>
      </div>
    )
  }
}

PreviewLink.propTypes = {
  path: PropTypes.string,
}

export default PreviewLink
