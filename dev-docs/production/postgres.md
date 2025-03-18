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

## Restore database from dump
```bash
# Only your local machine, get the dump from Herkou
heroku pg:backups:download # it downloads as latest.dump

scp latest.dump root@IP_OF_SERVER:/tmp

su - postgres
psql
# This would be a good time to rename the database, but make sure Rails connects to the new name.
CREATE DATABASE bank_production;
\q # exit

pg_restore --verbose -d bank_production latest.dump
```

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
