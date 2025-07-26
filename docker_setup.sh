#!/usr/bin/env bash

# installs all the dependencies for using HCB with Docker
# reach out to Max Wofford (max@hackclub.com) if you have any questions or issues

echo "
$(tput setaf 9)HCB:$(tput sgr0) Step 1/7: Install Heroku (Quiet)"
if ! command -v heroku &> /dev/null
then
  echo "running|||"
  (curl https://cli-assets.heroku.com/install.sh | sh) > /dev/null 2>&1
fi
echo "$(tput setaf 9)HCB:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"
echo "
$(tput setaf 9)HCB:$(tput sgr0) Step 2/7: Login to Heroku"
(heroku auth:whoami) > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "$(tput setaf 9)HCB:$(tput sgr0) Already signed in, skipping login..."
else
  echo "$(tput setaf 9)HCB:$(tput sgr0) Not signed in, sign in below"
  echo "$(tput setaf 9)HCB:$(tput sgr0) Use an API key generated from the Heroku Dashboard if you're using MFA"
  heroku login -i
fi
echo "$(tput setaf 9)HCB:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"
echo "
$(tput setaf 9)HCB:$(tput sgr0) Step 3/7: Connect to the Heroku Project"
heroku git:remote -a bank-hackclub > /dev/null
echo "$(tput setaf 9)HCB:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"
echo "
$(tput setaf 9)HCB:$(tput sgr0) Step 4/7: Get Heroku Backups"
if ! test -f "./latest.dump"; then
  heroku pg:backups:capture
  heroku pg:backups:download
fi
echo "$(tput setaf 9)HCB:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"

echo "
$(tput setaf 9)HCB:$(tput sgr0) Step 5/7: Copy .env file"
cp -n .env.development.example .env.development
echo "$(tput setaf 9)HCB:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"

echo "
$(tput setaf 9)HCB:$(tput sgr0) Step 6/7: Build Docker Container"
env $(cat .env.development) docker compose build
echo "$(tput setaf 9)HCB:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"

echo "
$(tput setaf 9)HCB:$(tput sgr0) Step 7/7: Docker Database Setup"
env $(cat .env.development) docker compose run --service-ports web bundle exec rails db:test:prepare RAILS_ENV=test
env $(cat .env.development) docker compose run --service-ports web bundle exec rails db:prepare
env $(cat .env.development) docker compose run --service-ports web pg_restore --verbose --clean --no-acl --no-owner -h db -U postgres -d bank_development latest.dump
echo "$(tput setaf 9)HCB:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"

if [[ $* == *--with-solargraph* ]]
then
  echo "$(tput setaf 9)HCB:$(tput sgr0) Step 8/7: Solargraph"
  env $(cat .env.development) docker compose -f docker-compose.yml -f docker-compose.solargraph.yml build
  echo "$(tput setaf 9)HCB:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"
fi

echo "
$(tput setaf 9)HCB:$(tput sgr0)
Run 'docker_start.sh' to start the dev server. You can run this command with the --with-solargraph flag to enable Solargraph."

echo "

Thank you for developing HCB!

Questions or issues with this script? Contact Max Wofford (max@hackclub.com)"

echo "
     @HCB@@@@@HCB@
    T             S
  H        $        T
 E       A   C       A
B    H           K    R
U      ©   H   A      T
C      C   K   C      S
K      L   U   B      H
 @    HCB HCB HCB    E
  @                 @
    HACK FOUNDATION

HCB, A Hack Club Project
© The Hack Foundation
"
