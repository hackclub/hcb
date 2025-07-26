echo "Shut down your rails server before continuing"
read -p "Press Enter to continue" </dev/tty

if [[ $* == *--codespace* ]]
then
  echo "dumping pg11 data"
  PGPASSWORD=postgres pg_dumpall --host db -U postgres | grep -Ev "^(CREATE|ALTER) ROLE" > pg11.dump

  echo "Make a copy of the pg11.dump file somewhere safe"
  read -p "Press Enter to continue" </dev/tty

  echo "load pg11 dump into pg15"
  PGPASSWORD=postgres psql --host db15 -U postgres < pg11.dump
else
  echo "starting pg11 db if it isn't already running"
  docker-compose up -d db

  echo "dumping pg11 data"
  docker exec hcb-db-1  /bin/bash -c "pg_dumpall --host db -U postgres | grep -Ev \"^(CREATE|ALTER) ROLE\" > pg11.dump"

  echo "copying pg11 data to host"
  docker cp hcb-db-1:/pg11.dump .

  echo "Make a copy of the pg11.dump file somewhere safe"
  read -p "Press Enter to continue" </dev/tty

  echo "shutting down pg11 db"
  docker-compose down db

  echo "starting pg15 db"
  docker-compose -f docker-compose.yml -f docker-compose.postgres-15.yml up -d db
  docker exec hcb-db-1 /bin/bash -c 'while !</dev/tcp/db/5432; do sleep 1; done;'

  echo "copying pg11 data to pg15 container"
  docker cp pg11.dump hcb-db-1:/

  echo "load pg11 dump into pg15"
  docker exec hcb-db-1 /bin/bash -c "psql -U postgres < pg11.dump"
fi
