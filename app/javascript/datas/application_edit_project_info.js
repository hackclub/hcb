import website_political_fields from './website_political_fields'

export default ({ has_website, has_political, committed, teenager }) => ({
  ...website_political_fields,
  has_website,
  has_political,
  committed,
  teenager,
})
