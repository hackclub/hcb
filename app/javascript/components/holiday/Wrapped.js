import React from 'react'
import HCBWrapped from '@hcb.gg/wrapped'
import PropTypes from 'prop-types'

export default function Wrapped({ data }) {
  return <HCBWrapped data={data} />
}

Wrapped.propTypes = {
  data: PropTypes.object.isRequired,
}
