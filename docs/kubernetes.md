---
title: Kubernetes Deployment
description: Kubernetes CronJob configurations for automated database snapshots with ConfigMap, Secret, and PersistentVolumeClaim examples
audience: users
doc_type: guide
tags: [kubernetes, k8s, cronjob, deployment, scheduling]
lastReviewed: 2025-11-15
version: 1.x
---

# Kubernetes Deployment

This page provides [Kubernetes](https://kubernetes.io){target="_blank"} configurations for scheduling automated database snapshots using [CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/){target="_blank"} resources.

## Overview

The recommended approach is to use Kubernetes [CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/){target="_blank"} resources to schedule backups at different frequencies. Each CronJob runs a snapshot container with a specific frequency argument (`hourly`, `daily`, `weekly`, `monthly`).

!!! warning "Your Responsibility"
    Please review the [Important Considerations](important-considerations.md) document. This package has not been reviewed for all possible use cases and environments. It should be considered an example, rather than a production-ready tool. Please ensure that you audit this package and how you deploy it against your specific environment and requirements.

## Basic Components

### ConfigMap

Store your configuration as a [ConfigMap](https://kubernetes.io/docs/concepts/configuration/configmap/){target="_blank"}:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mariadb-snapshot-config
  namespace: default
data:
  DB_HOSTNAME: "mysql.default.svc.cluster.local"
  DB_PORT: "3306"
  DB_USER_NAME: "snapshot_user"
  DB_SNAPSHOT_ALL_DATABASES: "true"
  DB_EXCLUDE_DATABASES: "information_schema,performance_schema,mysql,sys"
  DB_SNAPSHOT_COMBINED: "true"
  DB_STRUCT_TABLES: "cache_*,sessions"
  RSNAPSHOT_RETAIN_HOURLY: "24"
  RSNAPSHOT_RETAIN_DAILY: "14"
  RSNAPSHOT_RETAIN_WEEKLY: "8"
  RSNAPSHOT_RETAIN_MONTHLY: "12"
  GZIP_COMPRESSION_LEVEL: "9"
```

### Secret for Database Password

Store sensitive data in a [Secret](https://kubernetes.io/docs/concepts/configuration/secret/){target="_blank"}:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mariadb-snapshot-secret
  namespace: default
type: Opaque
stringData:
  DB_USER_PASSWORD: "your-secure-password-here"
```

### PersistentVolumeClaim for Backups

Create storage for backup files using a [PersistentVolumeClaim](https://kubernetes.io/docs/concepts/storage/persistent-volumes/){target="_blank"}:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mariadb-snapshot-storage
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
  storageClassName: standard  # Adjust to your storage class
```


## CronJob Configurations

### Hourly Backups

Run every hour at minute 0:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mariadb-snapshot-hourly
  namespace: default
spec:
  schedule: "0 * * * *"  # Every hour at minute 0
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 0
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: mariadb-snapshot
            image: jacobsanford/docker-mariadb-snapshot:1.x
            args: ["hourly"]
            envFrom:
            - configMapRef:
                name: mariadb-snapshot-config
            - secretRef:
                name: mariadb-snapshot-secret
            volumeMounts:
            - name: snapshot-storage
              mountPath: /data
            resources:
              requests:
                memory: "256Mi"
                cpu: "100m"
              limits:
                memory: "1Gi"
                cpu: "500m"
          volumes:
          - name: snapshot-storage
            persistentVolumeClaim:
              claimName: mariadb-snapshot-storage
```

### Daily Backups

Run daily at 2:00 AM:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mariadb-snapshot-daily
  namespace: default
spec:
  schedule: "0 2 * * *"  # Daily at 2:00 AM
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 0
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: mariadb-snapshot
            image: jacobsanford/docker-mariadb-snapshot:1.x
            args: ["daily"]
            envFrom:
            - configMapRef:
                name: mariadb-snapshot-config
            - secretRef:
                name: mariadb-snapshot-secret
            volumeMounts:
            - name: snapshot-storage
              mountPath: /data
            resources:
              requests:
                memory: "256Mi"
                cpu: "100m"
              limits:
                memory: "1Gi"
                cpu: "500m"
          volumes:
          - name: snapshot-storage
            persistentVolumeClaim:
              claimName: mariadb-snapshot-storage
```

### Weekly Backups

Run weekly on Sunday at 3:00 AM:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mariadb-snapshot-weekly
  namespace: default
spec:
  schedule: "0 3 * * 0"  # Sundays at 3:00 AM
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 0
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: mariadb-snapshot
            image: jacobsanford/docker-mariadb-snapshot:1.x
            args: ["weekly"]
            envFrom:
            - configMapRef:
                name: mariadb-snapshot-config
            - secretRef:
                name: mariadb-snapshot-secret
            volumeMounts:
            - name: snapshot-storage
              mountPath: /data
            resources:
              requests:
                memory: "256Mi"
                cpu: "100m"
              limits:
                memory: "1Gi"
                cpu: "500m"
          volumes:
          - name: snapshot-storage
            persistentVolumeClaim:
              claimName: mariadb-snapshot-storage
```

### Monthly Backups

Run monthly on the 1st at 4:00 AM:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mariadb-snapshot-monthly
  namespace: default
spec:
  schedule: "0 4 1 * *"  # 1st of month at 4:00 AM
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 0
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: mariadb-snapshot
            image: jacobsanford/docker-mariadb-snapshot:1.x
            args: ["monthly"]
            envFrom:
            - configMapRef:
                name: mariadb-snapshot-config
            - secretRef:
                name: mariadb-snapshot-secret
            volumeMounts:
            - name: snapshot-storage
              mountPath: /data
            resources:
              requests:
                memory: "256Mi"
                cpu: "100m"
              limits:
                memory: "1Gi"
                cpu: "500m"
          volumes:
          - name: snapshot-storage
            persistentVolumeClaim:
              claimName: mariadb-snapshot-storage
```

## Next Steps

- **[Configuration Reference](configuration.md)** - Detailed environment variable documentation
- **[Docker Compose Examples](docker-compose.md)** - Local deployment method
