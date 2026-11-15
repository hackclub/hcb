import React, { useState } from 'react'

const StripeChargeLookup = () => {
  const [search, setSearch] = useState('')
  const [results, setResults] = useState({})

  const handleChange = async event => {
    console.log('change occurred')
    const searchTerm = (event.target.value || '').trim()
    await setSearch(searchTerm)

    if (searchTerm == '') {
      return
    }
    console.log(results[searchTerm])
    if (results[searchTerm] || results[searchTerm] == 'loading...') {
      return
    }
    console.log('marking as loading')

    const loadingResults = { ...results }
    loadingResults[searchTerm] = 'loading...'
    await setResults(loadingResults)

    fetch(`/stripe_charge_lookup?id=${searchTerm}`)
      .then(d => d.json())
      .then(data => {
        const modifiedResults = { ...results }
        modifiedResults[searchTerm] = data
        setResults({ ...modifiedResults })
      })
      .catch(err => {
        const errorResults = { ...results }
        errorResults[searchTerm] = 'not found!'
        setResults(errorResults)
        console.log(err)
      })
  }

  return (
    <>
      <input
        type="text"
        onChange={handleChange}
        value={search}
        style={{ display: 'block' }}
      />

      <code
        style={{
          display: 'block',
          width: 'fit-content',
          minWidth: '25vw',
          minHeight: '3rem',
        }}
      >
        <pre>{JSON.stringify(results[search], null, 2)}</pre>
      </code>
    </>
  )
}

export default StripeChargeLookup
