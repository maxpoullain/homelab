#!/bin/bash

echo "=== ZFS Snapshot Performance Metrics ==="
echo ""

# 1. Current snapshot count
echo "Snapshot counts by dataset:"
for dataset in fast/apps fast/homes tank/backups tank/shared tank/media tank/users; do
  count=$(zfs list -t snapshot -r $dataset 2>/dev/null | wc -l)
  echo "  $dataset: $((count - 1)) snapshots"
done

echo ""

# 2. Fragmentation (high fragmentation = performance degradation)
echo "Dataset fragmentation:"
zpool list -o name,fragmentation fast tank

echo ""

# 3. ARC (cache) efficiency
echo "ARC cache statistics:"
arc_stats=$(cat /proc/spl/kstat/zfs/arcstats | grep -E "^(hits|misses|size)" | awk '{print $1 ": " $3}')
echo "$arc_stats"

echo ""

# 4. Recent snapshot creation times (from logs)
echo "Recent snapshot operations (last 10):"
journalctl -u zfs-snapshot-tasks -n 10 --no-pager 2>/dev/null || echo "  (logs not available)"

echo ""

# 5. I/O statistics per pool
echo "Pool I/O statistics:"
zpool iostat fast tank 1 3