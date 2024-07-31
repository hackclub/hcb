const js = require('@eslint/js')
const react = require('eslint-plugin-react/configs/recommended.js')
const reactHooks = require('eslint-plugin-react-hooks')
const globals = require('globals')

module.exports = [
  js.configs.recommended,
  react,
  {
    files: ['app/javascript/**/*.js'],
    rules: {
      'react/forbid-dom-props': ['error', { forbid: ['id'] }],
      ...reactHooks.configs.recommended.rules,
    },
    languageOptions: {
      globals: {
        ...globals.browser,
        require: 'readonly',
        PublicKeyCredential: 'readonly',
        process: 'readonly',
        AIRBRAKE_PROJECT_ID: 'readonly',
        AIRBRAKE_API_KEY: 'readonly',
      },
    },
    settings: {
      react: {
        version: 'detect',
      },
    },
    plugins: {
      'react-hooks': reactHooks,
    },
  },
]
