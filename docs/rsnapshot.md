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
Rotation only happens for the level you invoke. When you run:

```
rsnapshot daily
```

rsnapshot will:

Rotate the daily.* set (daily.6 → daily.7, ..., daily.0 → daily.1)

Create/refresh daily.0 from the live filesystem (using hard links to save space).

It will completely ignore the other levels:

hourly.*
weekly.*
monthly.*

Those are only rotated when you explicitly run:

```
rsnapshot hourly
rsnapshot weekly
rsnapshot monthly
```
