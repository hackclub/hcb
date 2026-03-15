bundle install
COREPACK_ENABLE_DOWNLOAD_PROMPT=0 yarn install
yarn build

sudo chown -R vscode:vscode /usr/local/bundle

# Setup PostgreSQL
bundle exec rails db:prepare
bundle exec rails db:test:prepare
bundle exec rails db:migrate
