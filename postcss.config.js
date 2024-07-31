module.exports = {
  syntax: 'postcss-scss',
  map: false,
  plugins: {
    '@csstools/postcss-sass': {},
    tailwindcss: {},
    autoprefixer: {},
    cssnano: process.env.NODE_ENV !== 'development' ? {} : false,
  },
}
