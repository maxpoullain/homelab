#!/bin/sh
#
# Tailscale Startup Script for QNAP TS-431
# Version: 1.1
# Tailscale Version: 1.104.1
#
# This script manages the Tailscale daemon on QNAP systems that don't support
# the official QPKG due to older QTS versions.
#
# Installation location: /share/CACHEDEV1_DATA/.qpkg/tailscale/tailscale_init.sh
#

export QNAP_QPKG=tailscale

# Paths
TAILSCALE_DIR="/share/CACHEDEV1_DATA/.qpkg/tailscale"
TAILSCALE_BIN="$TAILSCALE_DIR/bin/tailscaled"
TAILSCALE_CLI="$TAILSCALE_DIR/bin/tailscale"
STATE_FILE="$TAILSCALE_DIR/var/tailscaled.state"
SOCKET="/var/run/tailscale/tailscaled.sock"

# Logs
TAILSCALE_LOG="$TAILSCALE_DIR/var/tailscaled.log"
BOOT_LOG="$TAILSCALE_DIR/var/boot.log"

# Tailscale daemon options
# Using userspace-networking because kernel lacks TUN module support
TAILSCALE_OPTS="--state=$STATE_FILE --socket=$SOCKET --tun=userspace-networking"

# Full command registered with QNAP's daemon_mgr watchdog. start and stop
# MUST pass this identical string — daemon_mgr matches on it to find the
# right registry entry. If stop's string doesn't match what start
# registered, daemon_mgr won't flip the entry to "stop", and the watchdog
# relaunches the daemon within a second or two of killall, looking just
# like stop silently failed.
DAEMON_CMD="QNAP_QPKG=tailscale $TAILSCALE_BIN $TAILSCALE_OPTS >> $TAILSCALE_LOG 2>&1"

# Boot delay flag to avoid delay on manual restarts
BOOT_DELAY_FLAG="/tmp/.tailscale_boot_delay_done"

# True if a tailscaled process is already running.
# QNAP's daemon_mgr watchdog can relaunch tailscaled on its own (polling
# /etc/daemon_mgr.conf every ~30s), independently of this script. Without
# this check, "start" can race the watchdog and launch a second daemon.
is_running() {
  pidof tailscaled > /dev/null 2>&1
}

# Default action if none specified
ACTION=${1:-start}

# Log invocation for debugging
echo "$(date): Script called with parameter: '$ACTION'" >> $BOOT_LOG

case "$ACTION" in
  start)
    echo "$(date): Starting Tailscale..." >> $BOOT_LOG

    # Don't launch a second daemon if one (e.g. the daemon_mgr watchdog)
    # is already running. Doing the stale-socket cleanup below against a
    # live daemon would just orphan it.
    if is_running; then
      echo "$(date): Tailscale is already running, nothing to do" >> $BOOT_LOG
      exit 0
    fi

    # Wait for system to be fully ready during boot
    # This delay only happens once after boot, not on manual restarts
    if [ ! -f "$BOOT_DELAY_FLAG" ]; then
      echo "$(date): Waiting 30 seconds for system to be ready..." >> $BOOT_LOG
      sleep 30
      touch "$BOOT_DELAY_FLAG"
    fi
    
    # Create socket directory
    mkdir -p /var/run/tailscale
    
    # Clean up stale socket if it exists
    # This can happen if tailscaled crashed or was killed improperly
    if [ -S "$SOCKET" ]; then
      echo "$(date): Removing stale socket" >> $BOOT_LOG
      rm -f "$SOCKET"
    fi
    
    # Start Tailscale daemon using QNAP's daemon manager
    # The daemon_mgr ensures proper process management and logging.
    # Redirected and backgrounded: daemon_mgr's client call blocks in the
    # foreground until the daemon exits, which hangs a non-interactive
    # caller (e.g. `ssh host tailscale_init.sh start`).
    echo "$(date): Executing daemon_mgr..." >> $BOOT_LOG
    /sbin/daemon_mgr tailscaled start "$DAEMON_CMD" > /dev/null 2>&1 &
    
    # Wait for daemon to initialize
    sleep 3
    
    # Verify that tailscaled actually started
    if is_running; then
      echo "$(date): Tailscale started successfully" >> $BOOT_LOG
    else
      echo "$(date): WARNING - Tailscale may not have started" >> $BOOT_LOG
      echo "$(date): Check $TAILSCALE_LOG for errors" >> $BOOT_LOG
    fi
    ;;
    
  stop)
    echo "$(date): Stopping Tailscale..." >> $BOOT_LOG
    
    # Stop via daemon manager. Must pass the exact string registered by
    # "start" ($DAEMON_CMD) or daemon_mgr won't match the entry, won't flip
    # it to "stop", and its watchdog will relaunch the daemon right after
    # the killall below — making stop look like it silently failed.
    /sbin/daemon_mgr tailscaled stop "$DAEMON_CMD"
    
    # Ensure process is killed (fallback)
    killall tailscaled 2>/dev/null
    
    # Clean up socket
    rm -f "$SOCKET"
    
    echo "$(date): Tailscale stopped" >> $BOOT_LOG
    ;;
    
  restart)
    echo "$(date): Restarting Tailscale..." >> $BOOT_LOG
    $0 stop
    sleep 2
    $0 start
    ;;
    
  status)
    # Check if tailscaled is running
    if is_running; then
      echo "Tailscale is running"
      echo ""
      echo "Process:"
      ps | grep tailscaled | grep -v grep
      echo ""
      
      # Try to get Tailscale status if socket is available
      if [ -S "$SOCKET" ]; then
        echo "Tailscale Status:"
        $TAILSCALE_CLI --socket=$SOCKET status 2>/dev/null || echo "Unable to get status"
      fi
    else
      echo "Tailscale is not running"
      exit 1
    fi
    ;;
    
  log)
    # Follow the daemon log
    echo "Following Tailscale log (Ctrl+C to exit)..."
    tail -f $TAILSCALE_LOG
    ;;
    
  bootlog)
    # Show boot log
    cat $BOOT_LOG
    ;;
    
  ip)
    # Get Tailscale IP address
    if [ -S "$SOCKET" ]; then
      $TAILSCALE_CLI --socket=$SOCKET ip -4
    else
      echo "Tailscale is not running"
      exit 1
    fi
    ;;
    
  *)
    echo "Usage: $0 {start|stop|restart|status|log|bootlog|ip}"
    echo ""
    echo "Commands:"
    echo "  start    - Start Tailscale daemon"
    echo "  stop     - Stop Tailscale daemon"
    echo "  restart  - Restart Tailscale daemon"
    echo "  status   - Show Tailscale status"
    echo "  log      - Follow Tailscale daemon log"
    echo "  bootlog  - Show boot/startup log"
    echo "  ip       - Show Tailscale IP address"
    exit 1
    ;;
esac

exit 0