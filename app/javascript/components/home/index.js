// Explicitly import all home components to ensure they're in the webpack bundle
// This prevents "home is not defined" errors when loading via turbo frames
import Categories from './Categories'
import Merchants from './Merchants'
import Tags from './Tags'
import Users from './Users'

export { Categories, Merchants, Tags, Users }
