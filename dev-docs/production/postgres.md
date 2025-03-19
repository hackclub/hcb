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

ssh root@IP_OF_SERVER
su - postgres
psql
# This would be a good time to rename the database, but make sure Rails connects to the new name.
CREATE DATABASE bank_production;
\q # exit

pg_restore --verbose -d bank_production latest.dump
```

## Set up postgres user

### Allow connections
```bash
ssh root@IP_OF_SERVER
vim /etc/postgresql/15/main/pg_hba.conf
```

Add the following files to the file:
```
# TYPE  DATABASE        USER            ADDRESS                 METHOD
host    bank_production rails           10.0.1.0/24             md5
```

```bash
# Restart pogres
systemctl restart postgresql

```

### Create role
```bash
# Create postgres role (user)
su - postgres
psql
CREATE ROLE rails WITH INHERIT LOGIN CONNECTION LIMIT 500 PASSWORD 'password here';
```

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

### Provide database user access to read/write to the database
```sql
GRANT ALL PRIVILEGES ON SCHEMA public TO rails;
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
