# Postgres in Production

Runbook for how the production postgres database is setup and configured.

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
systemctl start postgresql.service

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
ssh root@IP_OF_SERVER
vim /etc/postgresql/15/main/pg_hba.conf
```

Add the following files to the file:
```
# TYPE  DATABASE        USER            ADDRESS                 METHOD
host    bank_production rails           10.0.1.0/24             md5

```

Change the following line
```
local   all             all                                     md5
```
to
```
local   all             all                                     md5
```

```bash
# Restart pogres
systemctl restart postgresql

```

## Set up postgres user

### Create role
```bash
# Create postgres role (user)
su - postgres
psql
# CREATE ROLE rails WITH INHERIT LOGIN CONNECTION LIMIT 500 PASSWORD 'password here';
CREATE USER rails WITH INHERIT CONNECTION LIMIT 500 PASSWORD 'password here';
```
- Heroku had a 500 connection limit, so we're mirroring that here.

### Verify connection from localhost
```bash
psql "postgres://rails:YOUR_PASSWORD@localhost:5432/bank_production"
```

### Edit postgresql.conf's listen addresses
```bash
vim /etc/postgresql/15/main/postgresql.conf
# Find the section that says:
#listen_addresses = 'localhost'         # what IP address(es) to listen on;

# and change it to:

listen_addresses = 'PRIVATE IP OF THE POSTGRES SERVER'           # what IP address(es) to listen on;
```

### Edit pg_hba.conf to allow `rails` user to connect from specific IPs
```bash
# TYPE  DATABASE        USER            ADDRESS                 METHOD
host    bank_production rails           10.0.1.0/24             md5
```

The Hetzner private network assigns IPs under 10.0.1.X (UPDATE: Technically it's
10.0.0.0/16)

## Restore database from dump
```bash
# Only your local machine, get the dump from Herkou
heroku pg:backups:download # it downloads as latest.dump

scp latest.dump root@IP_OF_SERVER:/tmp

ssh root@IP_OF_SERVER
su - postgres
psql
# This would be a good time to rename the database, but make sure Rails connects to the new name.
CREATE DATABASE bank_production WITH OWNER rails; # The database and all tables must be owned by rails
\q # exit

# Before running pg_restore, you may want to drop and recreate the database if
# it already exists. This is because the `--clean` flag will only drop tables
# that are in the dump.
# If the current database contains a table not reference in the dump, a future
# migration may run into a `relation "table_name" already exists` error.
#
# To drop database and recreate it, run:
#   DROP DATABASE bank_production;
#   CREATE DATABASE bank_production;

pg_restore --verbose --no-owner --no-acl --clean -d bank_production -U rails /tmp/latest.dump
```

### Provide database user access to read/write to the database

https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/create-application-users-and-roles-in-aurora-postgresql-compatible.html
To grant permission, use the following two:
```sql
GRANT ALL PRIVILEGES ON SCHEMA public TO rails;
-- GRANT USAGE ON SCHEMA public TO rails; -- seems to not be needed
GRANT all on all tables in schema public to rails;
```


## TODO

- [ ] Create a role with permissions that is used by the rails user. This will
  make it easier to rotate passwords in the future without needing to worry
  about reconfiguring permissions.
- [ ] Create separate role/permissions for migration vs app.
- [ ] Give rails user permission to create/manage extensions.

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
