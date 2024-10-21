export const colors = Array.from(
  { length: 11 },
  (_, i) => `hsl(352, 83%, ${70 - i * 5}%)`
)

export const shuffle = array => {
  for (let i = array.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[array[i], array[j]] = [array[j], array[i]]
  }
  return array
}
