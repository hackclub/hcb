bundle install
bin/rails db:migrate
yarn install
yarn build

sudo chown -R vscode:vscode /usr/local/bundle

# Setup PostgreSQL
bundle exec rails db:prepare
bundle exec rails db:test:prepare
