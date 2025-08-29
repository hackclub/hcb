#!/usr/bin/env bash

# starts the dev server with Docker
#  _   _  ____ ____
# | | | |/ ___| __ )
# | |_| | |   |  _ \
# |  _  | |___| |_) |
# |_| |_|\____|____/



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

echo "Thank you for developing HCB!
"

if [[ $* == *--with-solargraph* ]]
then
  docker compose -f docker-compose.yml -f docker-compose.solargraph.yml up -d solargraph
else
  echo "To enable Solargraph, run docker_start.sh with the --with-solargraph flag."
fi

# strip --with-solargraph and pass the remaining args to docker compose run
ARGS=()
for arg in "$@"; do
  [[ "$arg" != "--with-solargraph" ]] && ARGS+=("$arg")
done

docker compose run --service-ports web "${ARGS[@]}"
