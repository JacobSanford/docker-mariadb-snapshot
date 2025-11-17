---
title: Understanding the RSnapshot Configuration
description: How rsnapshot frequency labels and snapshot rotation work in docker-mariadb-snapshot
audience: users
doc_type: reference
tags: [rsnapshot, configuration, rotation, retention, scheduling]
lastReviewed: 2025-11-16
version: 1.x
---

# Understanding the rsnapshot Configuration

## 'Frequency' Labels
docker-mariadb-snapshot's environment variable names and rsnapshot configuration use the terms `hourly`, `daily`, `weekly`, and `monthly` to refer to different snapshot retention levels:

```
retain	hourly	RSNAPSHOT_RETAIN_HOURLY
retain	daily	RSNAPSHOT_RETAIN_DAILY
retain	weekly	RSNAPSHOT_RETAIN_WEEKLY
retain	monthly	RSNAPSHOT_RETAIN_MONTHLY
```

Although these appear to be time-based settings, it is important to understand __rsnapshot does not inherently understand time__. 'hourly', 'daily', 'weekly', and 'monthly' are simply labels for separate snapshot retention groups without any intrinsic time meaning. They could, in fact, be anything - 'red', 'blue', 'green', etc.

The actual frequency of when each level is executed is solely determined by the period in which you execute docker-mariadb-snapshot (e.g., via cron jobs).

## Snapshot Rotation
By default, rsnapshot uses a rotation mechanism to manage snapshots in a hierarchy. In the above-mentioned sample configuration, the daily, weekly, and monthly levels 'promote' and copy/link the oldest snapshot from the level above it __instead of creating a new snapshot from live data__. Snapshots are only ever taken (by default) at the hourly level, and the other levels simply rotate hourly snapshots down the hierarchy.

This default behavior is not ideal for accurate point-in-time restores. Instead, snapshots should be taken each time the image is run.

To accomplish this, docker-mariadb-snapshot sets the `sync_first     1` rsnapshot configuration item, which means __running docker-mariadb-snapshot with any frequency level as an argument will always snapshot the live data before performing the rotation__, and rotation only happens within the level you invoke.

This method is less efficient in terms of storage and snapshot time, but it guarantees that each snapshot level contains a full snapshot of the live data at the time of execution.

As an example: running docker-mariadb-snapshot with, say, the `daily` argument will:

* Create a new snapshot from the live filesystem.
* Rotate the daily.* set (daily.6 → daily.7, ..., daily.0 → daily.1)
* Set the new snapshot as daily.0.

It will completely ignore the other levels and never 'promote' snapshots from hourly to daily, daily to weekly, or weekly to monthly.
