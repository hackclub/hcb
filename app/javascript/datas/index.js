// Registers every component in this directory with Alpine under its filename,
// so `x-data="ach(...)"` resolves to `./ach.js`. Members that are spread into a
// component rather than registered as one live in `./shared`.

const context = require.context('.', false, /^\.\/(?!index\.js$).+\.js$/)

export default Alpine => {
  context.keys().forEach(key => {
    Alpine.data(key.slice(2, -3), context(key).default)
  })
}
