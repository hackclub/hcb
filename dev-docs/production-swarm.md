i gave us on this since Coolify has many bugs. Docker swarm on Coolify is not
Production ready...

# Production Hosting

Hetzner running Coolify

Docker swarm behind a Hetzner Load Balance

1. Create Hetzner Load Balancer
   `Name`: hcb-network
   `Zone`: us-east
   `IP range`: 10.0.0.0 / 16
2. Create Hetzner Placement Group
   `Name`: hcb-placement
   `Type`: Spread
3. Create Hetzner server
   `Location`: us-east
   `Image`: Ubuntu 24.04
   `Type`: CCX13 (Dedicated, 2 vCPU AMD, 8 GB, 80 GB SSD)
   `Networking`:
   - Private network (`hcb-network`)
   - IPv4: `hcb-app-server-a_primary-ip`
   - IPv4: ipv6
   `SSH keys`: `coolify-hcb-ssh-key` and `garyhtou`
   `Firewalls`: will be configured later
   `Placement groups`: `hcb-placement`

   Create three of these:
   - `hcb-app-server-a`
   - `hcb-app-server-b`
   - `hcb-app-server-c`
4. Add servers to Coolify
   - `Name`: hcb-app-server-a
   - `Description`: App/job server A
   - `IP Address`: from hetzner
   - `Swarm Manager`: keep this off for now. I ran into a Docker install issue
      when this is turned on during initial "Validate & Configure".

   For each server, `Validate & configure` on Coolify.
   It's Install Docker, etc.

5. Turn on `Swarm Manager` for all servers on Coolify.
6. Create `gary@hcb` app
7. Create GitHub app (`hcb-github-app`); named `HCB Coolify` on GitHub
8. In `gary@hcb` app:
   - Hook up project to `hcb` repo
   - Use Dockefile as Build Pack
   - In Servers tab,
      - Choose `hcb-app-server-a` as main server
      - Add `hcb-app-server-b` and `c` as additional servers.
   - In General tab,
      - Set Docker image name to `ghcr.io/hackclub/hcb`. This name is largely
        dictated by ghcr.io (GitHub
        Packages) — [docs](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#pushing-container-images).
      - Leave Docker Image Tag empty (Empty means to `latest`)
      - Set Dockerfile Location to `/production.Dockerfile`
   - In Swarm Configuration,
      - Uncheck "Only Start on Worker nodes". (all of our hosts will be manager nodes).
      - And I'll set replicas to 2, for now.
   - In Health Check tab,
      - Set Path as [`/up`](https://github.com/hackclub/hcb/pull/9534).
   - Configure resource limits
9. Set up Docker Registry (using GitHub Packages). On GitHub, create a Personal
   Access Token (classic) by following instructions
   here: https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry
   - I also gave it `delete:packages` scope. https://github.com/settings/tokens/new?scopes=write:packages,delete:packages
   - ssh into ALL servers (yes, `a`, `b`, and `c`, etc.)
     ```bash
     docker login ghcr.io -u garyhtou # substitute your username
     # It'll prompt for a password. Paste in your PAT (classic).
     ```
   - While you're in there, follow Coolify's Docker swarm setup instructions
      - Skip docker install; it's already installed
      - Configure Docker
        ```bash
        systemctl start docker
        systemctl enable docker
        ```
        Since we're on Hetzner, we also need to configure the MTU. Coolify's
        docs seem to expect for the `/etc/docker/daemon.json` file to NOT
        already exist. For me, it did exist. So, instead of running their code
        which I believe would override the existing configuration, I manually
        used vim to add the additional JSON. Here's what my `daemon.json` looked
        like at the end.
        
        ```json
        {
          "log-driver": "json-file",
          "log-opts": {
            "max-size": "10m",
            "max-file": "3"
          },
          "default-network-opts": {
            "overlay": {
              "com.docker.network.driver.mtu": "1450"
            }
          }
        }
        ```

        Then, restart Docker.
        ```bash
        systemctl restart docker
        ```
      - Create Swarm cluster.

        We'll save this for later.
10. Deploy `gary@hcb` to test Docker registry

    It should build the Docker image, push it to GitHub Packages, then deploy
    it. Since we have two replicas, it should deploy two instances of the
    service. We can check this by running `docker service ls` on any of the
    servers.

    You should get a success build and deploy, but a failure with the following
    message:
    ```
    this node is not a swarm manager. Use "docker swarm init" or "docker swarm join" to connect this node to swarm and try again
    ```
11. Set up Docker Swarm cluster.
    Back to
    these [instructions by Coolify](https://coolify.io/docs/knowledge-base/docker/swarm#create-a-swarm-cluster).
    But honestly, they weren't great so also read the [official Docker docs](https://docs.docker.com/engine/swarm/swarm-tutorial/create-swarm/).
    ```bash
    # SSH into `hcb-app-server-a`
    
    # Get `hcb-app-server-a`'s private network IP address handy. It should look
    # like 10.0.0.x. At the time of writing, it's `10.0.0.2`. Check on Hetzner.
    docker swarm init --advertise-addr <HCB-APP-SERVER-A PRIVATE IP HERE>

    # The command above will print a join command. Don't use that
    # We'll generate a new join command for joining as a manager.

    docker swarm join-token manager
    
    # Then, for each the other servers (hcb-app-server-b, hcb-app-server-c, etc.),
    # run the following command printed by the command above. It should look
    # something like:
    #
    # docker swarm join --token SWMTKN-blah-blah 10.0.0.blah:2377
    
    # A successful response is: "This node joined a swarm as a manager."
    ``` 
    
    To verify that the swarm is set up correctly, run the following from any
    manager. In our case, this should be any server (since they're all managers).
    ```bash
    docker node ls
    ```
    Example response:
    ```
    ID                            HOSTNAME           STATUS    AVAILABILITY   MANAGER STATUS   ENGINE VERSION
    ar70so00b03o3503mlud28lsm     hcb-app-server-a   Ready     Active         Leader           27.5.1
    8yqzfddb1r9hehvsbfezzy057     hcb-app-server-b   Ready     Active         Reachable        27.5.1
    v6dz5gvjw4nzj56g7egzosnoo *   hcb-app-server-c   Ready     Active         Reachable        27.5.1
    ```
12. ~~fight coolify~~Delete and re-add all server to get Coolify to generate
    the right Destination and `coolify-overlay` network.

    First "disconnect" apps from servers. You'll likely need to leave one server
    connected. If so, perform the following steps on the N-1 servers, then switch
    apps over the the new servers and repeat the steps on the last server.

    For each server:
    1. Open server's settings
    2. Copy IP address
    3. Delete server
    4. Add new server
    5. Paste IP address (and set name)
    6. Check Docker Swarm Manager
    7. Save and Validate & Configure

    Then, go back to `gary@hcb` app and add all server back.

13. Deploy `gary@hcb` again to Docker Swarm cluster.

    It should actually successfully deploy this time.

14. Set up Hetzner load balancer
    - private network
    - TLS passthrough

