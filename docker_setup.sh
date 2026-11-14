#!/usr/bin/env bash

# installs all the dependencies for using HCB with Docker
# reach out to Max Wofford (max@hackclub.com) if you have any questions or issues

echo "
$(tput setaf 9)HCB:$(tput sgr0) Step 1/3: Copy .env file"
cp -n .env.development.example .env.development
echo "$(tput setaf 9)HCB:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"

echo "
$(tput setaf 9)HCB:$(tput sgr0) Step 2/3: Build Docker Container"
env $(cat .env.development) docker compose build
echo "$(tput setaf 9)HCB:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"

echo "
$(tput setaf 9)HCB:$(tput sgr0) Step 3/3: Docker Database Setup"
env $(cat .env.development) docker compose run --service-ports web bundle exec rails db:test:prepare RAILS_ENV=test
env $(cat .env.development) docker compose run --service-ports web bundle exec rails db:prepare
echo "$(tput setaf 9)HCB:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"

if [[ $* == *--with-solargraph* ]]
then
  echo "$(tput setaf 9)HCB:$(tput sgr0) Step 4/3: Solargraph"
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
