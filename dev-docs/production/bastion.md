# Bastion host

_Also known as a Jumpbox or (SSH Tunneling)._

For security, none of our servers are directly accessible via the public
internet—this includes our webservers and Postgres. We have firewalls configured
to block all inbound connections that originate from outside the private
network. The only exception is the Bastion host which allows for external SSH
connections.

All of HCB's servers are on the same private network. This means that each
server within the private network is able to communicate with other servers
using private IP addresses (generally in `10.0.0.0/16`). This is how the Rails
application is able to connect to the Postgres server **_without_ ** need to use
a Bastion host/SSH Tunneling.

However, if you are attempting to connect to HCB's Postgres or any HCB server
from outside the private network, you'll need to use the Bastion host. Some
common use cases of this includes:

- SSHing into HCB's servers from your laptop.
- Accessing HCB's postgres from your laptop.
- Connecting HCB's postgres to a 3rd party tool such as Metabase or Fivetran.

## Policy regarding access to HCB's servers

- To provision access, you must get explicit approval from @garyhtou.
- **Defense in Depth**.
  By default, just gaining access to the Bastion host will not provide you
  access to HCB's resources. There is _at least_ one additional level of
  authentication. For example,
    - To access the Rails console, you must also have SSH access to the app
      severs.
    - To access Postgres, you must have a valid user/password in Postgres.
- **Least privilege principle**.
  Give the least permissions possible. If a user only needs Postgres access,
  don't provide SSH access to the HCB app servers. In addition, when creating a
  Postgres user, give it the least amount of privilege possible. A simple
  example here is: The Metabase Postgres user only has read-only access for very
  specific tables.
- Do not share accounts. Each service/human/reason-for-access should have its
  own login/credentials. This allows for auditability, reduces the chance of
  leaking credentials (when attempting to share them), and limits the risk
  and scope of access when credentials are compromised.
- Must use SSH key authentication for Bastion host. Passwords are too weak. If
  there are situations where SSH key authentication is infeasible, please chat
  with @garyhtou.
- Ideally, the bastion host username should be the same the user configured
  within the resource. For example, if the bastion host username is `orpehus`,
  then the Postgres user should be `oprheus`.
- Don't publicly share the IP addresses of the bastion host or any servers.
  Security via obscurity can't be relied upon, however, there is no need to
  share this information publicly. The only IP address that the public should be
  aware of is the IP of the load balancer.

## How to provision Bastion host account

In this example, we'll be creating an account for a user named `orpheus`.

1. Obtain (or generate) SSH public key.
    - If this is an account for a human, ask them for their SSH public key
    - If this is an account for a service, sometime they'll generate and provide
      and SSH public key. For example, Hatchbox and Fivetran will generate that
      SSH public key for you. If the service does not automatically generate an
      SSH key pair for you, you can manually do that. I recommend [GitHub's
      instructions](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent).

2. SSH into bastion host as root.
   ```bash
   ssh root@IP_OF_BASTION
   ```
3. Create the linux user
   ```bash
   useradd -m orpheus
   ```
   The `-m` option automatically creates their home directory.
4. Add the SSH public key
   ```bash
   su - orpheus
   mkdir ~/.ssh
   vim ~/.ssh/authorized_keys
   # Paste in the public key and save (`:wq`)
   ```
5. (Optional) I'd recommend changing the default shell from `/bin/sh` to
   `/bin/bash`. To do this, as `root`, run:
   ```bash
   usermod -s /bin/bash orpehus
   ```
6. Provision resource-specific access.
   I'm not providing specific instructions here since the process is different
   for each resource.
    - If you're providing Postgres access, create the user in Postgres and grant
      permissions.
    - If you're providing Rails console access, you'll also need to add their
      SSH key to the app server(s). This can be done manually or via the
      Hatchbox console. Note that when adding an SSH key via Hatchbox, that will
      provide root access to all Hatchbox managed servers (app, job, and redis
      servers). _Best practice TBD._
7. Testing provisioned access
    1. SSH into the Bastion host.
       If you have access to the new user's private key:
       ```bash
       ssh orpehus@IP_OF_BASTION -i /path/to/orpheus/ssh_private_key
       ```
       Otherwise, SSH in as root and switch user to new user.
       ```bash
       ssh root@IP_OF_BASTION
       su - orpehus
       ```
    2. Test resource-specific access.
        - If you're testing Postgres access:
           ```bash
            psql "postgres://orpheus:PASSWORD_HERE@PRIVATE_IP_OF_POSTGRES:5432/hcb_production"
           ```
          _**Hint:** In some shells, prefixing your command with a space (` `)
          will
          not save it to your shell history._

        - If you're testing Rails console access:
          ```bash
          ssh PRIVATE_IP_OF_APP_SERVER
          # Then following instruction prompt. Likely...
          cd ~/HCB/current && bundle exec rails c
          ```
          The process for accessing the Rails console process may change, so I'm
          leaving it intentionally vague here.

~ @garyhtou
