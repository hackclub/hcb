import Intl from 'intl'
import 'intl/locale-data/jsonp/en-US'
import { useEffect, useState } from 'react'

export const generateColor = (i, isDark) => {
  const lightness = isDark ? 20 + (Math.min(i, 10) * 5) : 60 - (Math.min(i, 10) * 5);
  return `hsl(352, 83%, ${lightness}%)`;
};

export const USDollar = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
})

export const USDollarNoCents = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
  minimumFractionDigits: 0,
  maximumFractionDigits: 0,
})

export const useDarkMode = () => {
  const [isDarkMode, setIsDarkMode] = useState(false)

  useEffect(() => {
    const currentTheme = document.documentElement.getAttribute('data-dark')
    setIsDarkMode(currentTheme === 'true')

    // Observer to watch for changes to data-theme attribute
    const observer = new MutationObserver(() => {
      const updatedTheme = document.documentElement.getAttribute('data-dark')
      setIsDarkMode(updatedTheme === 'true')
    })

    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['data-dark'],
    })

    return () => {
      observer.disconnect()
    }
  }, [])

  return isDarkMode
}
