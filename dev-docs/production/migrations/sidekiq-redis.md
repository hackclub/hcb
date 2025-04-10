# Migrating Sidekiq's Redis

We store our queue of jobs in a Redis instance. When / if we change hosting providors, we can't lose that data.

Here are the steps to do the migration:

1) Ensure that AOF persistence is enabled in the new server's Redis configuration, [view Redis' docs](https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/) for more context. This should be as simple as changing `appendonly no` to `appendonly yes` in the `redis.conf` (`/etc/redis/redis.conf` when using Hatchbox).
2) Install [RIOT](https://github.com/redis/riot) locally (or any where you like to work!).
3) Turn on maintenance mode and disable Sidekiq - this is to prevent new jobs being added to the queue.
4) Run the following command to migrate the keys from your old Redis instance to your new Redis instance:
  
    ```
    riot replicate [old_connection_string] [new_connection_string]
    ```
    
    If migrating from Heroku, you'll need to add `--source-insecure --no-ttl` [(context)](https://stackoverflow.com/questions/65042551/ssl-certification-verify-failed-on-heroku-redis/). Read more on [redis.github.io](https://redis.github.io/riot/#_replication).
5) Change `REDIS_URL` in your enviroment variables.
6) Turn off maintenance mode, enable Sidekiq and verify the queue has migrated!
