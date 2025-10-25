#!/bin/bash

echo "Creating snapshot tasks for all datasets..."

# ============================================
# FAST POOL
# ============================================

# fast/apps - Hourly + Daily + Weekly + Monthly
midclt call pool.snapshottask.create '{
  "dataset": "fast/apps",
  "recursive": true,
  "lifetime_value": 24,
  "lifetime_unit": "HOUR",
  "naming_schema": "auto-%Y%m%d-%H%M-hourly",
  "schedule": {"minute": "0", "hour": "*"}
}'

midclt call pool.snapshottask.create '{
  "dataset": "fast/apps",
  "recursive": true,
  "lifetime_value": 7,
  "lifetime_unit": "DAY",
  "naming_schema": "auto-%Y%m%d-%H%M-daily",
  "schedule": {"minute": "0", "hour": "2"}
}'

midclt call pool.snapshottask.create '{
  "dataset": "fast/apps",
  "recursive": true,
  "lifetime_value": 4,
  "lifetime_unit": "WEEK",
  "naming_schema": "auto-%Y%m%d-%H%M-weekly",
  "schedule": {"minute": "0", "hour": "3", "dow": "7"}
}'

midclt call pool.snapshottask.create '{
  "dataset": "fast/apps",
  "recursive": true,
  "lifetime_value": 3,
  "lifetime_unit": "MONTH",
  "naming_schema": "auto-%Y%m%d-%H%M-monthly",
  "schedule": {"minute": "0", "hour": "4", "dom": "1"}
}'

# fast/homes - Hourly + Daily + Weekly
midclt call pool.snapshottask.create '{
  "dataset": "fast/homes",
  "recursive": true,
  "lifetime_value": 24,
  "lifetime_unit": "HOUR",
  "naming_schema": "auto-%Y%m%d-%H%M-hourly",
  "schedule": {"minute": "15", "hour": "*"}
}'

midclt call pool.snapshottask.create '{
  "dataset": "fast/homes",
  "recursive": true,
  "lifetime_value": 7,
  "lifetime_unit": "DAY",
  "naming_schema": "auto-%Y%m%d-%H%M-daily",
  "schedule": {"minute": "15", "hour": "2"}
}'

midclt call pool.snapshottask.create '{
  "dataset": "fast/homes",
  "recursive": true,
  "lifetime_value": 4,
  "lifetime_unit": "WEEK",
  "naming_schema": "auto-%Y%m%d-%H%M-weekly",
  "schedule": {"minute": "15", "hour": "3", "dow": "7"}
}'

# ============================================
# TANK POOL - System/Backups
# ============================================

# tank/backups - Daily + Weekly
midclt call pool.snapshottask.create '{
  "dataset": "tank/backups",
  "recursive": true,
  "lifetime_value": 30,
  "lifetime_unit": "DAY",
  "naming_schema": "auto-%Y%m%d-%H%M-daily",
  "schedule": {"minute": "0", "hour": "4"}
}'

midclt call pool.snapshottask.create '{
  "dataset": "tank/backups",
  "recursive": true,
  "lifetime_value": 8,
  "lifetime_unit": "WEEK",
  "naming_schema": "auto-%Y%m%d-%H%M-weekly",
  "schedule": {"minute": "0", "hour": "5", "dow": "7"}
}'

# tank/shared - Daily + Weekly + Monthly
midclt call pool.snapshottask.create '{
  "dataset": "tank/shared",
  "recursive": true,
  "lifetime_value": 7,
  "lifetime_unit": "DAY",
  "naming_schema": "auto-%Y%m%d-%H%M-daily",
  "schedule": {"minute": "30", "hour": "2"}
}'

midclt call pool.snapshottask.create '{
  "dataset": "tank/shared",
  "recursive": true,
  "lifetime_value": 4,
  "lifetime_unit": "WEEK",
  "naming_schema": "auto-%Y%m%d-%H%M-weekly",
  "schedule": {"minute": "30", "hour": "3", "dow": "7"}
}'

midclt call pool.snapshottask.create '{
  "dataset": "tank/shared",
  "recursive": true,
  "lifetime_value": 6,
  "lifetime_unit": "MONTH",
  "naming_schema": "auto-%Y%m%d-%H%M-monthly",
  "schedule": {"minute": "30", "hour": "4", "dom": "1"}
}'

# ============================================
# TANK POOL - Media (Recursive with exclusions)
# ============================================

# tank/media - Weekly + Monthly (recursive, excludes downloads)
midclt call pool.snapshottask.create '{
  "dataset": "tank/media",
  "recursive": true,
  "exclude": ["tank/media/downloads"],
  "lifetime_value": 4,
  "lifetime_unit": "WEEK",
  "naming_schema": "auto-%Y%m%d-%H%M-weekly",
  "schedule": {"minute": "0", "hour": "6", "dow": "7"}
}'

midclt call pool.snapshottask.create '{
  "dataset": "tank/media",
  "recursive": true,
  "exclude": ["tank/media/downloads"],
  "lifetime_value": 3,
  "lifetime_unit": "MONTH",
  "naming_schema": "auto-%Y%m%d-%H%M-monthly",
  "schedule": {"minute": "0", "hour": "6", "dom": "1"}
}'

# tank/media/photos - Additional daily snapshots (important data)
midclt call pool.snapshottask.create '{
  "dataset": "tank/media/photos",
  "recursive": true,
  "lifetime_value": 7,
  "lifetime_unit": "DAY",
  "naming_schema": "auto-%Y%m%d-%H%M-daily",
  "schedule": {"minute": "30", "hour": "5"}
}'

# ============================================
# TANK POOL - Users (Recursive)
# ============================================

# tank/users - Daily + Weekly + Monthly (recursive for all users)
midclt call pool.snapshottask.create '{
  "dataset": "tank/users",
  "recursive": true,
  "lifetime_value": 7,
  "lifetime_unit": "DAY",
  "naming_schema": "auto-%Y%m%d-%H%M-daily",
  "schedule": {"minute": "0", "hour": "3"}
}'

midclt call pool.snapshottask.create '{
  "dataset": "tank/users",
  "recursive": true,
  "lifetime_value": 4,
  "lifetime_unit": "WEEK",
  "naming_schema": "auto-%Y%m%d-%H%M-weekly",
  "schedule": {"minute": "0", "hour": "4", "dow": "7"}
}'

midclt call pool.snapshottask.create '{
  "dataset": "tank/users",
  "recursive": true,
  "lifetime_value": 6,
  "lifetime_unit": "MONTH",
  "naming_schema": "auto-%Y%m%d-%H%M-monthly",
  "schedule": {"minute": "0", "hour": "5", "dom": "1"}
}'

echo "All snapshot tasks created successfully!"
echo ""
echo "Summary:"
echo "  - fast/apps: Hourly(24) + Daily(7) + Weekly(4) + Monthly(3)"
echo "  - fast/homes: Hourly(24) + Daily(7) + Weekly(4)"
echo "  - tank/backups: Daily(30) + Weekly(8)"
echo "  - tank/shared: Daily(7) + Weekly(4) + Monthly(6)"
echo "  - tank/media: Weekly(4) + Monthly(3) [excluding downloads]"
echo "  - tank/media/photos: Daily(7) [additional]"
echo "  - tank/users: Daily(7) + Weekly(4) + Monthly(6)"
echo ""
echo "Verify with: midclt call pool.snapshottask.query"