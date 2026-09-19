const TEAM_EMAIL =
  /(team|webmaster|marketing|admin|info|about|support|sales|hello)/

export default () => ({
  email: '',

  get is_team_email() {
    return TEAM_EMAIL.test(this.email)
  },
})
