# Postgres in Production

Runbook for how the production postgres database is setup and configured.

Portions of this docs contains processes/commands specific to the migration from
Heroku postgres to our own self hosted postgres.

## Provision servers on Hetzner

- us-east
- Ubuntu
- Dedicated vCPU
    - CCX13 (2 AMD vCPUS, 8gb RAM, 80gb SSD,, 1TB traffic. $14.49/month)
- Network. Attach to same private network as rest of HCB servers
- Add your SSH key
- SSH only firewall
- Placement group: `hcb-postgres-placement`

We want to create two of these e.g.

- `server-postgres-1`
- `server-postgres-2`

# Shared instructions (regardless of primary or replica):

## Install PostgreSQL on a new Ubuntu server

```bash
apt update

# Add Postgres' Apt server
# https://wiki.postgresql.org/wiki/Apt
apt install -y postgresql-common
/usr/share/postgresql-common/pgdg/apt.postgresql.org.sh

apt install postgresql-15
apt install libpq-dev
```

## Ensure Postegres is running

```bash
# Ensure systemd service config for Postgres exists
cat /usr/lib/systemd/system/postgresql.service
# Make sure it prints something

# Start postgres using Systemctl
systemctl start postgresql.service # This shouldn't be necessary since the apt install automatically starts it

# You can validate that' it's running using
ps aux | grep postgres
```

## Check you can connect with PSQL

```bash
# To access with PSQL
su - postgres
psql # This will NOT working unless you're the `postgres` linux user.
```

## Allow connections

```bash
# switch back to root. If you `su - postgres`'ed earlier, then you can simpily `exit`
vim /etc/postgresql/15/main/pg_hba.conf
```

Add the following files to the file:

```
# TYPE  DATABASE        USER            ADDRESS                 METHOD
host    hcb_production  rails           10.0.1.0/16             scram-sha-256
```

This allows the `rails` user to connect from specific IPs (any in the local
network).
The Hetzner private network assigns IPs under 10.0.0.0/16 by default.

# "local" is for Unix domain socket connections only

local all all scram-sha-256

```

```bash
# Restart postgres
systemctl restart postgresql
```

### Edit postgresql.conf's listen addresses

```bash
vim /etc/postgresql/15/main/postgresql.conf
# Find the section that says:
#listen_addresses = 'localhost'         # what IP address(es) to listen on;

# and change it to:

listen_addresses = 'PRIVATE IP OF THE POSTGRES SERVER'           # what IP address(es) to listen on;
```

You can get the server's private IP from the Hetzner dashboard

```bash
# Restart pogres
systemctl restart postgresql
```

# Primary server specific instructions

## Set up postgres user

### Create role

Create postgres role (user)

```bash
su - postgres
psql
# Create rails user
CREATE USER rails WITH INHERIT CONNECTION LIMIT 500 PASSWORD 'password here';

# Create the database so that we can test connecting to it in the next step.
CREATE DATABASE hcb_production WITH OWNER rails;
```

- Heroku had a 500 connection limit, so we're mirroring that here.

### Verify connection from another server in the local network

```bash
psql "postgres://rails:YOUR_PASSWORD@IP_ADDRESS_OF_PRIMARY_SERVER:5432/hcb_production"
```

```SQL
DROP DATABASE hcb_production;
```

### Provide database user access to read/write to the database

https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/create-application-users-and-roles-in-aurora-postgresql-compatible.html
To grant permission, use the following two:

```sql
GRANT ALL PRIVILEGES ON SCHEMA public TO rails;
-- GRANT USAGE ON SCHEMA public TO rails; -- seems to not be needed
GRANT all on all tables in schema public to rails;
```

## Install pgBackRest

On primary...

https://pgbackrest.org/user-guide.html#quickstart:~:text=C%20/build/pgbackrest-,Installation,-A%20new%20host

```bash
apt-get install pgbackrest

# Ensure postgres user can run it
sudo -u postgres pgbackrest --help

```

Follow guide
https://pgbackrest.org/user-guide.html#quickstart:~:text=for%20more%20information.-,Quick%20Start,-The%20Quick%20Start

### Install

Guide's step 5:

```
sudo mkdir -p -m 770 /var/log/pgbackrest
sudo chown postgres:postgres /var/log/pgbackrest
sudo mkdir -p /etc/pgbackrest
sudo mkdir -p /etc/pgbackrest/conf.d
sudo touch /etc/pgbackrest/pgbackrest.conf
sudo chmod 640 /etc/pgbackrest/pgbackrest.conf
sudo chown postgres:postgres /etc/pgbackrest/pgbackrest.conf
```

### Configure Stanza

Guide's step 6.2, 6.5, 6.6, and 15:

- [Chapter 15](https://pgbackrest.org/user-guide.html#multi-repo:~:text=azure%20%2D%2Dstanza%3Ddemo-,S3%2DCompatible%20Object%20Store%20Support,-pgBackRest%20supports%20locating)

```bash 
vim /etc/pgbackrest/pgbackrest.conf
```

```sql
[hcb_production]
pg1-path=/var/lib/postgresql/15/main

[global]
process-max=4
repo1-path=/pgbackrest/server-postgres-3
repo1-retention-full-type=time
repo1-retention-full=30
repo1-s3-bucket=hcb-production-postgres
repo1-s3-endpoint=fsn1.your-objectstorage.com
repo1-s3-key=REPLACE_ME
repo1-s3-key-secret=REPLACE_ME
repo1-s3-region=fsn1
repo1-type=s3
repo1-cipher-pass=REPLACE_ME
repo1-cipher-type=aes-256-cbc
repo1-bundle=y
repo1-block=y4
start-fast=compress-type=zsty
```

You'll want to create an object storage on Hetzner and add credentials.

Creds are stored in HCB Engineering 1Password

### Configure archiving

Follow chapter 6.4, but with these changes:

```
archive_command = 'pgbackrest --stanza=demo archive-push %p'
max_wal_senders = 10
wal_level = replica
```

We'll leave `#archive_mode = off` until after the `pg_restore`

### Create stanza

Follow chapter 6.7

```bash
sudo -u postgres pgbackrest --stanza=hcb_production --log-level-console=info stanza-create
```

You can check the configuration by running

```bash
sudo -u postgres pgbackrest --stanza=hcb_production --log-level-console=info check
```

Since we have `archive_mode = off`, we should expect see:

```
root@server-postgres-3:~# sudo -u postgres pgbackrest --stanza=hcb_production --log-level-console=info check
2025-03-26 05:58:11.771 P00   INFO: check command begin 2.54.2: --exec-id=5676-95949e22 --log-level-console=info --pg1-path=/var/lib/postgresql/15/main --repo1-cipher-pass=<redacted> --repo1-cipher-type=aes-256-cbc --repo1-path=/pgbackrest/server-postgres-3 --repo1-s3-bucket=hcb-production-postgres --repo1-s3-endpoint=fsn1.your-objectstorage.com --repo1-s3-key=<redacted> --repo1-s3-key-secret=<redacted> --repo1-s3-region=fsn1 --repo1-type=s3 --stanza=hcb_production
2025-03-26 05:58:11.798 P00  ERROR: [087]: archive_mode must be enabled
2025-03-26 05:58:11.798 P00   INFO: check command end: aborted with exception [087]
```

## Dry run of restore database from dump

```bash
# On your local machine, get the dump from Herkou
heroku pg:backups:capture
heroku pg:backups:download # it downloads as latest.dump

scp latest.dump root@IP_OF_PRIMARY_SERVER:/tmp

ssh root@IP_OF_SERVER
su - postgres
psql
# This would be a good time to rename the database, but make sure Rails connects to the new name.
CREATE DATABASE hcb_production WITH OWNER rails; # The database and all tables must be owned by rails
\q # exit

# Before running pg_restore, you may want to drop and recreate the database if
# it already exists. This is because the `--clean` flag will only drop tables
# that are in the dump.
# If the current database contains a table not reference in the dump, a future
# migration may run into a `relation "table_name" already exists` error.
#
# To drop database and recreate it, run:
#   DROP DATABASE hcb_production;
#   CREATE DATABASE hcb_production WITH OWNER rails;

pg_restore --verbose --no-owner --no-acl --clean -d hcb_production -U rails /tmp/latest.dump
```

## Ensure you can read/write to the database from another server on the same network

```bash
# ssh into another server on the same network
psql "postgres://rails:YOUR_PASSWORD@IP_ADDRESS_OF_PRIMARY_SERVER:5432/hcb_production"
```

```sql
# attempt a read and write
SELECT *
from events
order by id desc
limit 1;

UPDATE users
SET full_name = 'testingsadflkjsdf'
WHERE id = 1803;

# verify write worked
SELECT full_name
from users
where id = 1803
limit 1;
```

## Do the restore for real

```sql
DROP DATABASE hcb_production;
CREATE DATABASE hcb_production WITH OWNER rails;
```

Shut down all traffic and write to current database/production

1. Turn on maintenance mode on Hatchbox
2. Disable all processes (e.g. Sidekiq, etc.)

After traffic has been shutdown, perform the last write to the DB.

```sql
UPDATE users
SET full_name = 'last update lkasdjf'
WHERE id = 1803;

# verify write worked
SELECT full_name
from users
where id = 1803
limit 1;
```

```bash
# On your local machine, get the dump from Herkou
heroku pg:backups:capture
heroku pg:backups:download # it downloads as latest.dump

scp latest.dump root@IP_OF_PRIMARY_SERVER:/tmp

ssh root@IP_OF_SERVER
su - postgres
psql
# This would be a good time to rename the database, but make sure Rails connects to the new name.
CREATE DATABASE hcb_production WITH OWNER rails; # The database and all tables must be owned by rails
\q # exit

# Before running pg_restore, you may want to drop and recreate the database if
# it already exists. This is because the `--clean` flag will only drop tables
# that are in the dump.
# If the current database contains a table not reference in the dump, a future
# migration may run into a `relation "table_name" already exists` error.
#
# To drop database and recreate it, run:
#   DROP DATABASE hcb_production;
#   CREATE DATABASE hcb_production WITH OWNER rails;

pg_restore --verbose --no-owner --no-acl --clean -d hcb_production -U rails /tmp/latest.dump
```

Verify last write is there:

```sql
SELECT full_name
from users
where id = 1803
limit 1;
```

Roll password of `rails` user

```sql
ALTER USER rails WITH PASSWORD 'new_password';
```

## Start archiving

Update archive_mode to on in postgresql.conf

```bash
sudo -u postgres pgbackrest --stanza=hcb_production --log-level-console=info check
sudo -u postgres pgbackrest info
```

Check the S3 bucket for files

## Start traffic

Update env var

```
DATABASE_URL=postgres://rails:password@INTERNAL_IP_OF_PRIMARY_SERVER:5432/hcb_production
# and update BLAZER_DATABASE_URL
```

1. Enable all processes (e.g. Sidekiq, etc.)
2. Turn off maintenance mode on Hatchbox

----

## Replication

### Create a new database server

follow instructions above

### Configure `cluster_name` for each database server

> Set the cluster_name parameter to be the server name in the postgresql.conf
> file.
> - PostgreSQL 16 Administration Cookbook

Remember to `systemctl restart postgresql`.

### Create replication user on primary

```sql
CREATE USER repuser
    REPLICATION
    LOGIN
    CONNECTION LIMIT 2
    ENCRYPTED PASSWORD 'changeme';
```

### Allow replication user to connect

Add the following line to pg_hba.conf on the primary node:

```
host    replication     repuser         PRIVATE_IP_OF_POSTGRES_2_SERVER/32             scram-sha-256
```

### Stop relica postgres and delete it's data directory

```bash
systemctl stop postgresql
rm -rf /var/lib/postgresql/15/main
```

### `bg_basebackup`

```bash
pg_basebackup -d 'host=10.0.1.5 user=repuser' -D /var/lib/postgresql/15/main -R -P
# TODO: add --create-slot and --slot 
```

### Configure replica

```sql
SELECT *
FROM pg_create_physical_replication_slot('server_postgres_2_slot');
SELECT slot_name, slot_type, active
FROM pg_replication_slots;
# slot_name        | slot_type | active
# ------------------------+-----------+--------
#  server_postgres_2_slot | physical  | f
```

vim /etc/postgresql/15/main/postgresql.conf

# set primary_conninfo

# set primary_slot_name

## TODO

- [ ] Practice restoring from pgBackRest
- [ ] Setup jumpbox, create metabase user, and reconnect metabase
- [ ] Create a role with permissions that is used by the rails user. This will
  make it easier to rotate passwords in the future without needing to worry
  about reconfiguring permissions.
- [ ] Create separate role/permissions for migration vs app.
- [ ] Give rails user permission to create/manage extensions.
- [ ] Set up notifications for failed backups.
    - Ensure it works if the entire server is down.
- [ ] Set up postgres monitoring (either separate tool or with Appsignal)

# Notes

```bash
# Better alternative to find
# https://github.com/sharkdp/fd
apt-install fd-find
```

# Postgres' config is located at

```
/etc/postgresql/15/main/pg_hba.conf
```

~ @garyhtou + @albertchae
