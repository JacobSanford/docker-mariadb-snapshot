---
title: Understanding the RSnapshot Configuration
description: How rsnapshot frequency labels and snapshot rotation work in docker-mariadb-snapshot
audience: users
doc_type: reference
tags: [rsnapshot, configuration, rotation, retention, scheduling]
lastReviewed: 2026-10-30
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
docker-mariadb-snapshot uses rsnapshot's standard rotation, with the `sync_first     1`
configuration item. Only the **lowest retained level** (the first `retain` line left in the
configuration, normally `hourly`, or `daily` when `RSNAPSHOT_RETAIN_HOURLY` is `0`) takes a new
snapshot of the live data. Every higher level promotes the oldest snapshot of the level below
it and does not connect to the database at all.

As an example, with `RSNAPSHOT_RETAIN_HOURLY=0` and the default daily, weekly and monthly
retention, running docker-mariadb-snapshot with:

* `daily` creates a new snapshot from the live data in `.sync`, rotates the daily set
  (daily.5 → daily.6, ..., daily.0 → daily.1), and makes the new snapshot daily.0.
* `weekly` rotates the weekly set and moves the oldest daily (daily.6) to weekly.0. Nothing is
  dumped. Until seven dailies exist there is nothing to promote, and rsnapshot logs
  `daily.6 not present (yet), nothing to copy`.
* `monthly` does the same with the oldest weekly (weekly.3).

A weekly or monthly snapshot is therefore the point-in-time snapshot taken by the lowest level
when it ran, not a snapshot taken when the weekly or monthly job ran. Its
`snapshot-metadata.json` records that original run, including `"frequency": "daily"`.

Every level you schedule must have a non-zero retention, and the lowest level must run often
enough to feed the levels above it. A level that is retained but never run (for example the
image's default `hourly` retention when only `daily`, `weekly` and `monthly` are scheduled)
becomes the lowest level, and then nothing is ever promoted. Set its retention to `0`.

Before 2026-10-30 every level dumped the live data before rotating. Higher levels then
discarded that dump, because they promote from the level below rather than from `.sync`.

## Failed Runs
rsnapshot runs the dump script with its working directory in `<snapshot_root>/tmp`, then copies
the results into `.sync`. When the script exits non-zero, rsnapshot rolls `.sync` back to the
newest snapshot of the lowest level, discarding every file from that run. The image then stops
without rotating and exits with rsnapshot's non-zero status, so nothing changes on disk and the
orchestrator sees a failure.
