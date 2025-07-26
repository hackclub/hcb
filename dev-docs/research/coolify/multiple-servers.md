# Coolify /w Multiple Servers Feature

TLDR:

- Multiple Hetzner servers behind a TLS Terminating Load Balancer
- Coolify manages those servers
- Rails app is deployed on all app servers by Coolify (via Docker) and Docker
  containers are mapped to host's port 80
- Coolify does not run a proxy (e.g. no Traefik)

## Set up process

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

   Create two of these:
    - `hcb-app-server-a`
    - `hcb-app-server-b`
4. Add servers to Coolify
    - `Name`: hcb-app-server-a
    - `Description`: App/job server A (and App/job server B)
    - `IP Address`: get it from hetzner

   For each server, `Validate & configure` on Coolify.
   It's Install Docker, etc.
5. For each server, display the default Traefik proxy.
    - Click on each server, then click "Stop proxy" on the top right.
    - Go to the Proxy tab, click "switch proxy", select None.
6. Create `gary@hcb` app
7. Create GitHub app (`hcb-github-app`); named `HCB Coolify` on GitHub
8. In `gary@hcb` app:
    - Hook up project to `hcb` repo
    - Use Dockefile as Build Pack
    - In General tab,
        - Set Docker image name to `ghcr.io/hackclub/hcb`. This name is largely
          dictated by ghcr.io (GitHub
          Packages) — [docs](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#pushing-container-images).
        - Docker Image Tag: `latest`
        - Dockerfile Location: `/production.Dockerfile`
        - Ports exposed: `3000`
        - Ports mappings: `80:3000` (`80` on host, `3000` in container)
        - Domains: Leave blank!
          ([according to the docs](https://coolify.io/docs/knowledge-base/server/multiple-servers#port-mapping-to-host))
    - In Servers tab,
        - Choose `hcb-app-server-a` as main server
        - Add `hcb-app-server-b` and `c` as additional servers.
    - In Health Check tab,
        - Set Path as [`/up`](https://github.com/hackclub/hcb/pull/9534).
    - Configure resource limits
        - Set swappiness to 10
9. Deploy `gary@hcb`
    - Verify that you can access it using `ip:port`.
      You must pick a path that does NOT redirect you.
      For example, the Rails app will redirect `/` to `/users/auth` when you're
      not signed in. This redirect goes to `https` (not `http`) and will result
      in a error.
    - I personally recommend `curl`'ing the `/up` health check path. For
      example,
      ```
      curl http://1.2.3.4:80/up
      ```
10. Configure firewall
    - Inbound Rule: Any IPv4, Any IPv6, TCP, 22
    - Apply to all servers, include the build server
11. Set up Hetzner load balancer
    1. Create load balancer `hcb-lb-a`
        - Targets: all app servers (exclude the build server)
    2. User certbot to manually create a SSL certificate.
       On my mac...

       **Install certbot**
       ```bash
       brew install certbot
       ```

       **Verify it's installed**
       ```bash
       certbot --version
       ```
       ```
       certbot 3.1.0
       ```

       **Generate the certificate** using manual mode and DNS challenge.
        - I have hcb-test.hackclub.com in there since i'm making sure this works
          before switching real prod over.
        - {config,work,logs}-dir are set to prevent certbot from polluting my
          machine .
       ```bash
       certbot certonly --manual --preferred-challenges dns \
         -d hcb.hackclub.com,hcb-test.hackclub.com \
         --config-dir ~/Downloads/certbot/config \
         --work-dir ~/Downloads/certbot/work \
         --logs-dir ~/Downloads/certbot/log
       ```
        - Follow the prompts (enter your email, etc.)
        - You'll then be asked to deploy a DNS TXT record. That can be done at
          [hackclub/dns](https://github.com/hackclub/dns)
        - Once the DNS record(s) are deployed, press enter to continue. Certbot
          will write the certificate and key to disk.
          ```
          Successfully received certificate.
          Certificate is saved at: /Users/garyhtou/Downloads/certbot/config/live/hcb.hackclub.com/fullchain.pem
          Key is saved at:         /Users/garyhtou/Downloads/certbot/config/live/hcb.hackclub.com/privkey.pem
          This certificate expires on 2025-05-13.
          These files will be updated when the certificate renews.
          ```
    3. Upload the certificate to Hetzner.
        - Go to `Security` on the sidebar. Then the `Certificates` tab
        - Click `Upload certificate`
        - Fill in the form
            - `Name`: `hcb-certificate-exp-2025-02-12` (includes today's date)
            - `Certificate`: Copy the contents of `fullchain.pem`
            - `Private key`: Copy the contents of `privkey.pem`
    4. Destroy the certbot files that were created on your machine.
       ```bash
       rm -rf ~/Downloads/certbot
       ```
    5. Finish setting up the load balancer
        - Go to the load balance's settings and add a new service.
        - Use the `TLS Termination` template. It should look like:
            - Protocol: HTTPS
            - Source Port: 443
            - Destination Port: 80
            - HTTP-Redirect (301): checked
        - Select the certificate you uploaded earlier
        - Configure the health check. We can use Rail's `/up` endpoint here.
            - Protocol: HTTP
            - Port: 80
            - Path: `/up`
        - Save it!
12. Load balancer's IP is an A (and AAAA) record at `ingress.hcb.hackclub.com`
    - The intention is that the IP address of our underlying servers are never
      exposed publicly.
13. `hcb.hackclub.com` is a CNAME for `ingress.hcb.hackclub.com`

oh yeah, i also added a build server. shared cpu, 4vCPU, 8gb. Make sure that's
added to Coolify AND configured to be a build server.

- In the app, tick the checkbox that says use build server.

---

## Setting up new VPS

1. Allow
   swap: https://www.digitalocean.com/community/tutorials/how-to-add-swap-space-on-ubuntu-20-04
    - Follow all the way through
    - I have swap set to 16G at the moment, however, I plan to scale the servers
      such that swap is not used.
2. Add the server to Coolify
    - It'll handle installing Docker which is necessary for the next step.
3. Docker login to Docker Registry (GitHub Packages). On GitHub, create a
   Personal Access Token (classic) by following instructions
   here: https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry
    - I also gave it `delete:packages`
      scope. https://github.com/settings/tokens/new?scopes=write:packages,delete:packages
    - ssh into ALL servers (yes, `a`, `b`, and `c`, etc.)
      ```bash
      docker login ghcr.io -u garyhtou # substitute your username
      # It'll prompt for a password. Paste in your PAT (classic).
      ```

   Alternatively, if you've already done this one on a server, you can copy the
   `~/.docker/config.json` file from the older server to the new server.

---

## Coolify internals

- Read the code: https://github.com/coollabsio/coolify
- If you need to figure out the exact docker compose file that Coolify generated
  and deployed with, it's located on each server at:
  ```
  /data/coolify/applications/<application id>
  ```
  Application ID can be retrieved from the URL of the app in Coolify's
  dashboard.

  The docker compose file is located at
  ```
  /data/coolify/applications/<application id>/docker-compose.yaml
  ```
  In that same directory, there's also a `README.md` that contains the
  human-readable name of the application — useful so you don't need to go
  digging in the Coolify dashboard for the app ID. Just trial, error, and
  confirm with the README.
