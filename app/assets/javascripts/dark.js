// This script is only used to set the theme when the cookie `theme` is set to `system`

try {
  ; (function () {
    const isThemeExplicitlySet = ['dark', 'light'].includes(document.cookie.split('; ').find(row => row.startsWith('theme='))?.split('=')[1]);
    const isSystemDark = window.matchMedia('(prefers-color-scheme: dark)').matches;

    if (!isThemeExplicitlySet) {
      document.querySelector('html').setAttribute('data-dark', isSystemDark)
      document.querySelector('meta[name=theme-color]')?.setAttribute('content', isSystemDark ? "#17171d" : '#f9fafc')
    }
  })()
} catch (e) {
  console.log('Dark theme script error:', e)
}
