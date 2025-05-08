# AppSignal Standalone Agent for Postgres servers

Follow install instructions for Ubuntu
https://docs.appsignal.com/standalone-agent/installation/linux-package.html

1. apt-get install curl gnupg apt-transport-https
2. curl -L https://packagecloud.io/appsignal/agent/gpgkey | sudo apt-key add -
3. Confirm file doesn't exist
   ```bash
   less /etc/apt/sources.list.d/appsignal_agent.list
   ```
4. Create file
   ```bash
   touch /etc/apt/sources.list.d/appsignal_agent.list
   ```
5. Write to file.
   Copied from their docs, but replaced `lunar` with `noble` since we're running
   Ubuntu 24.
   _^ this may change in the future!_
   ```
   deb https://packagecloud.io/appsignal/agent/ubuntu/ noble main
   deb-src https://packagecloud.io/appsignal/agent/ubuntu/ noble main
   ```
6. Install it
   ```bash
   apt-get update
   apt-get install appsignal-agent
   ```

7. It should have created `/etc/appsignal-agent.conf`, check to see if it exists
   ```bash
   less /etc/appsignal-agent.conf
   ```
8. Configure it
   ```bash
   vim /etc/appsignal-agent.conf
   ```
   ```text
   # AppSignal agent configuration
   
   # Configure the agent with the following minimal configuration. These can also
   # be set through environment variables.
   #
   # For more information, see our documentation on the agent configuration:
   # https://docs.appsignal.com/standalone-agent/configuration.html
   
   push_api_key = "REPLACE ME"
   app_name = "HCB"
   environment = "production"
   ```
   There is also a `hostname` option, but no need to specify since AppSignal
   will automatically derive that.
9. Start it
   ```bash
   systemctl start appsignal-agent
   ```

Yay! You should see the new host in `Host Metrics` on the AppSignal dashboard.

To see logs, run:

```bash
journalctl -u appsignal-agent
```

~ @garyhtou & @albertchae
