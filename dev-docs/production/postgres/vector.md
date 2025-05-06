# Vector (Postgres monitoring for AppSignal)

1. Install vector
   https://vector.dev/docs/setup/installation/package-managers/apt/
   ```bash
   bash -c "$(curl -L https://setup.vector.dev)"
   apt-get install vector
   ```

2. vim /etc/vector/vector.yaml
   ```yaml
   #                                    __   __  __
   #                                    \ \ / / / /
   #                                     \ V / / /
   #                                      \_/  \/
   #
   #                                    V E C T O R
   #                                   Configuration
   #
   # ------------------------------------------------------------------------------
   # Website: https://vector.dev
   # Docs: https://vector.dev/docs
   # Chat: https://chat.vector.dev
   # ------------------------------------------------------------------------------
   
   # Change this to use a non-default directory for Vector data storage:
   # data_dir: "/var/lib/vector"
   
   # Source metrics from Postgres
   sources:
     postgresql:
       type: "postgresql_metrics"
       # Due to HCB's pg_hba.conf, the private IP must be used instead of localhost
       endpoints: [ "postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@PRIVATE_IP:5432/$POSTGRES_DB" ]
   
   # Send metrics to AppSignal
   sinks:
     appsignal:
       type: "appsignal"
       inputs: [ "postgresql" ]
       push_api_key: "REPLACE ME"
   
   # Vector's GraphQL API (disabled by default)
   # Uncomment to try it out with the `vector top` command or
   # in your browser at http://localhost:8686
   # api:
   #   enabled: true
   #   address: "127.0.0.1:8686"
   ```

3. Create Postgres user
   ```
   CREATE USER vector WITH PASSWORD 'password here';
   
   # Based on https://vector.dev/docs/reference/configuration/sources/postgresql_metrics/#required-privileges
   grant select on pg_stat_database, pg_stat_database_conflicts, pg_stat_bgwriter to vector;
   ```
   And update the connection string in the yaml config
4. Validate vector config
   ```bash
   vector validate
   ```

5. Start Vector
   ```bash
   systemctl start vector
   ```

6. Verify that data is flowing.
   I recommend running the following commands. Although, you'll need
   `api.enabled = true` to be set in the config.
   ```bash
   vector top
   vector tap
   ```

7. Wait for AppSignal to pick up custom metrics from Vector. It should
   automagically create a Postgres dashboard.

   ![AppSignal sidebar](https://hc-cdn.hel1.your-objectstorage.com/s/v3/f8d29276865f37c091d9f8d7e46d3586877b2970_image.png)
   ![AppSignal automatically PostgreSQL dashbaord](https://hc-cdn.hel1.your-objectstorage.com/s/v3/43730e54bc305ea2bce6b7e6d82c200889bc3b90_image.png)

~ @garyhtou & @albertchae
