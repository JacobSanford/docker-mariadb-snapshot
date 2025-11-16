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

/usr/bin/rsnapshot -c /etc/rsnapshot.conf sync
/usr/bin/rsnapshot -c /etc/rsnapshot.conf $FREQUENCY
