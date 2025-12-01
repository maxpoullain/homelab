#!/bin/sh
#
# Tailscale Startup Script for QNAP TS-431
# Version: 1.0
# Tailscale Version: 1.90.6
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

# Boot delay flag to avoid delay on manual restarts
BOOT_DELAY_FLAG="/tmp/.tailscale_boot_delay_done"

# Default action if none specified
ACTION=${1:-start}

# Log invocation for debugging
echo "$(date): Script called with parameter: '$ACTION'" >> $BOOT_LOG

case "$ACTION" in
  start)
    echo "$(date): Starting Tailscale..." >> $BOOT_LOG
    
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
    # The daemon_mgr ensures proper process management and logging
    echo "$(date): Executing daemon_mgr..." >> $BOOT_LOG
    /sbin/daemon_mgr tailscaled start "$TAILSCALE_BIN $TAILSCALE_OPTS >> $TAILSCALE_LOG 2>&1" &
    
    # Wait for daemon to initialize
    sleep 3
    
    # Verify that tailscaled actually started
    if ps | grep -v grep | grep tailscaled > /dev/null; then
      echo "$(date): Tailscale started successfully" >> $BOOT_LOG
    else
      echo "$(date): WARNING - Tailscale may not have started" >> $BOOT_LOG
      echo "$(date): Check $TAILSCALE_LOG for errors" >> $BOOT_LOG
    fi
    ;;
    
  stop)
    echo "$(date): Stopping Tailscale..." >> $BOOT_LOG
    
    # Stop via daemon manager
    /sbin/daemon_mgr tailscaled stop "$TAILSCALE_BIN"
    
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
    if ps | grep -v grep | grep tailscaled > /dev/null; then
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
      return 1
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
      return 1
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