# Understanding RSnapshot Configuration

## 'Frequency' Labels
This image's environment variable names and rsnapshot configuration use the terms `hourly`, `daily`, `weekly`, and `monthly` to refer to different snapshot retention levels:

```
retain	hourly	RSNAPSHOT_RETAIN_HOURLY
retain	daily	RSNAPSHOT_RETAIN_DAILY
retain	weekly	RSNAPSHOT_RETAIN_WEEKLY
retain	monthly	RSNAPSHOT_RETAIN_MONTHLY
```

Although these appear to be time-based settings, it is important to understand __rsnapshot does not inherently understand time__. 'hourly', 'daily', 'weekly', and 'monthly' are simply labels for separate snapshot retention groups without any intrinsic time meaning. They could, in fact, be anything - 'red', 'blue', 'green', etc.

The actual frequency of when each level is executed is solely determined by how you schedule rsnapshot (e.g., via cron jobs).

## Snapshot Rotation
By default, rsnapshot uses a rotation mechanism to manage snapshots in a hierarchy. In the above configuration, the daily,weekly, and monthly levels 'promote' the oldest snapshot from the level above it __instead of creating a new snapshot from live data__.

docker-mariadb-snapshot instead leverages the `sync_first     1` rsnapshot configuration item. Consequently, __running docker-mariadb-snapshot with any frequency level as an argument will always snapshot the live data before performing the rotation__, and rotation only happens within the level you invoke.

This is less efficient in terms of storage and snapshot time, but it guarantees that each snapshot level contains a full snapshot of the live data exactly at the time of execution.

Therefore, running docker-mariadb-snapshot with a `daily` argument will execute as follows

rsnapshot will:

Rotate the daily.* set (daily.6 → daily.7, ..., daily.0 → daily.1)

Create a new daily.0 daily snapshot from the live filesystem.

It will completely ignore the other levels and never 'promote' snapshots from hourly to daily, daily to weekly, or weekly to monthly.
