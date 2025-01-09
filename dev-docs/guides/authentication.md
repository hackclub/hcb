# Authentication on HCB
HCB’s authentication system is an awkward hodgepodge of systems, built one on top of the other. I’m going to start by off by listing off the models and their purpose:

* `Login`: stores information about an attempt to login, whether successful or not. It’s created when someone enters their email address and either expires or ends after they’ve provided one or two factors of authentication, which creates a `UserSession`.
* `LoginCode`: is a temporary code sent via email to users, they can use this code as authentication factor.
  * `LoginCodeService::Request` confusingly can also send SMS login codes, however, these don’t have an associated `LoginCode` record and are done through Twilio. 
* `User::Totp`: a TOTP credential that users can use to login. One-per-user.
* `WebauthnCredential`: a WebAuthn credential that users can use to login, eg. a fingerprint or a Yubikey. Users can have multiple.
* `UserSession`: created after a successful `Login`. Has a `session_token` that is set as a browser cookie.

## Logging in

Logging in starts in the `LoginsController`, the `new` route renders the page for users to enter their email (`/users/auth` points there). That form submits to the `create` route, which will create a `Login` record.

From there, it’ll set a cookie that’ll act as the “browser token”. It will be used to make sure that this `Login` record is only used in this browser.

If this computer has a `login_preference` set (using [Rails’ sessions](https://guides.rubyonrails.org/v4.1/action_controller_overview.html#session)), it will redirect you to either `totp_login_path` or `login_code_login_path`. Otherwise, it will redirect you to `choose_login_preference_login_path` or `login_code_login_path` if you don’t have TOTP / WebAuthn setup. 

`login_code_login_path` will send the user a login code via email or SMS based on their preference (stored in the `use_sms_auth` column). They can manually override this by setting `resp[:method] = :sms` . It then renders a form for them to enter this code.

`totp_login_path` renders a form for users to input their one time password.

`set_login_preference` simply gives uses a list of options to set their `login_preference` by POST-ing to `choose_login_preference`.

The forms on both `login_code_login_path` and `totp_login_path` submit to `complete_login_path`. 

The complete method does two things:

1) It verifies whether what the user inputted is valid. Is it a valid login code / one time password etc.? Once verified it will mark that method as completed on the login record as follows: `@login.update(authenticated_with_webauthn: true)`. This is done so that we can keep track of unique factors used for two factor authentication.
2) It transitions the `Login` record to complete, if possible. This is done when the user has authenticated with the required amount of factors (1 or 2, depending on if 2FA is enabled). That is determined in an AASM state guard clause on the `Login` model.

Lastly, if the login is complete, this line signs the user in:

```ruby
@login.update(user_session: sign_in(user: @login.user, fingerprint_info:))
```

### WebAuthn

WebAuthn credentials are done slightly differently to login codes and TOTPs. Instead of having a dedicated path, when the user submits the form on `new_login_path` or selects _Security key / fingerprint_ on `choose_login_preference`, we make a fetch request to `/users/webauthn/auth_options` to see if they have a WebAuthn credential available and then prompt them to use it on that page. If anything in that stage fails, we submit the form as usual to `create_login_path`. 

If WebAuthn is available and the security key works in the browser, we make a request to `complete_login_path` or `complete_logins_path`. The reason for  `complete_logins_path` is that if this is the form where you input your email, a `Login` record won’t have been created.

We use GitHub’s `@github/webauthn-json` package and most of this logic is contained in `webauthn_auth_controller.js`.

## Fingerprinting

We fingerprint every user session using `@fingerprintjs/fingerprintjs`. This is passed into the `UserSession` created inside of `complete_login_path`.

\- [@sampoder](https://github.com/sampoder)
