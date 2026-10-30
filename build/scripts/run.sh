#!/usr/bin/env sh
for i in /scripts/pre-init.d/*sh
do
  if [ -e "${i}" ]; then
    echo "[i] pre-init.d - processing $i"
    . "${i}"
  fi
done

FREQUENCY=${1:-hourly}
export SNAPSHOT_FREQUENCY=$FREQUENCY

echo "Configuration:"
cat /etc/rsnapshot.conf
echo "Generating Snapshots..."

# Only the lowest retained level takes a new snapshot of the live data. rsnapshot turns
# .sync into a new generation only for that level; every higher level promotes the oldest
# generation of the level below it. A sync before a higher level's rotation would dump the
# databases and then discard the result, since nothing reads .sync until the lowest level
# next runs and the next sync overwrites it.
LOWEST_LEVEL=$(awk '$1 == "retain" { print $2; exit }' /etc/rsnapshot.conf)

if [ "$FREQUENCY" = "$LOWEST_LEVEL" ]; then
  /usr/bin/rsnapshot -c /etc/rsnapshot.conf sync
else
  echo "Skipping sync: '$FREQUENCY' is not the lowest retained level ('$LOWEST_LEVEL'); promoting only."
fi
/usr/bin/rsnapshot -c /etc/rsnapshot.conf $FREQUENCY
