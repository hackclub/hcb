#!/usr/bin/env bash

# installs dependencies with Docker Compose and seeds the development database
# reach out to Max Wofford (max@hackclub.com) if you have any questions or issues

echo "
$(tput setaf 9)HCB:$(tput sgr0) Step 1/5: Copy .env file"
cp -n .env.development.example .env.development
echo "$(tput setaf 9)HCB:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"

echo "
$(tput setaf 9)HCB:$(tput sgr0) Step 2/5: Build Docker Container"
docker compose build
echo "$(tput setaf 9)HCB:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"

echo "
$(tput setaf 9)HCB:$(tput sgr0) Step 3/5: Docker Database Setup"
docker compose run --service-ports web bundle exec rails db:test:prepare RAILS_ENV=test
docker compose run --service-ports web bundle exec rails db:create db:schema:load # We're not using `db:prepare` because we want to run `db:seed` later
echo "$(tput setaf 9)HCB:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"

echo "
$(tput setaf 9)HCB:$(tput sgr0) Step 4/5: Create development user"
docker compose up -d >/dev/null 2>&1
echo "Go to localhost:3000 and login to create your development user"
read -p "Press Enter to continue" </dev/tty
docker compose down
echo "$(tput setaf 9)HCB:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"

echo "
$(tput setaf 9)HCB:$(tput sgr0) Step 5/5: Development Database Seeding"
docker compose run --service-ports web bundle exec rails db:seed
echo "$(tput setaf 9)HCB:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"


if [[ $* == *--with-solargraph* ]]
then
  echo "$(tput setaf 9)HCB:$(tput sgr0) Step 6/5: Solargraph"
  docker compose -f docker-compose.yml -f docker-compose.solargraph.yml build
  echo "$(tput setaf 9)HCB:$(tput sgr0) $(tput setaf 10)Done$(tput sgr0)"
fi

echo "
$(tput setaf 9)HCB:$(tput sgr0)
Run 'docker compose up' to start the dev server. You can run this command with the --with-solargraph flag to enable Solargraph."

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
