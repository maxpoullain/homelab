#!/bin/sh
#
# Beszel Agent Startup Script for QNAP TS-431
# Version: 1.1
# Beszel Version: 0.21.0
#
# This script manages the Beszel agent on QNAP systems running an older QTS
# (4.x): no systemd and no Docker, so neither the official install script nor
# the container image can be used.
#
# Connection mode is SSH: the hub dials the agent over the tailnet
# (<tailscale-ip>:45876). tailscaled runs in userspace-networking mode and
# forwards inbound tailnet TCP for its own IP to 127.0.0.1, so the agent only
# listens on loopback and is not reachable from the LAN.
#
# Unlike tailscale_init.sh this does NOT use QNAP's daemon_mgr. On a "start"
# that follows a "stop", daemon_mgr kills the agent 20-30s later and launches
# its own copy, while the daemon_mgr client that launched the first one
# relaunches it too. Both copies survive, because the agent doesn't exit when
# its port is taken (it retries every 10s). Instead, "start" launches a small
# supervisor loop of our own that relaunches the agent if it ever exits.
#
# Installation location: /share/CACHEDEV1_DATA/.qpkg/beszel-agent/beszel_init.sh
#

export QNAP_QPKG=beszel-agent

# Paths
AGENT_DIR="/share/CACHEDEV1_DATA/.qpkg/beszel-agent"
SELF="$AGENT_DIR/beszel_init.sh"
AGENT_BIN="$AGENT_DIR/bin/beszel-agent"
KEY_FILE="$AGENT_DIR/etc/key"
DATA_DIR="$AGENT_DIR/var"
PID_FILE="$AGENT_DIR/var/supervisor.pid"
FAKE_SYS="/tmp/beszel-fakesys"

# Logs
AGENT_LOG="$AGENT_DIR/var/beszel-agent.log"
BOOT_LOG="$AGENT_DIR/var/boot.log"

# Agent environment, see https://beszel.dev/guide/environment-variables
# Defaults can be overridden by the caller, e.g.
#   LOG_LEVEL=debug /share/CACHEDEV1_DATA/.qpkg/beszel-agent/beszel_init.sh foreground
agent_env() {
  # Hub public key(s), from the hub's "Add System" dialog
  export KEY_FILE
  # Persistent directory (/ is a RAM disk on QTS)
  export DATA_DIR
  # Loopback only: the hub reaches the agent through tailscaled
  export LISTEN="${LISTEN:-127.0.0.1:45876}"
  # / is a 61 MB RAM disk, report the data volume as the main disk instead
  export FILESYSTEM="${FILESYSTEM:-/share/CACHEDEV1_DATA__Data}"
  # Hide every md array: md9/md13 (24 raid slots, 3 used: permanent WARNING),
  # the md256/md322 swap mirrors, and md1 (data array, permanent WARNING from
  # its stale mismatch_cnt). Real disk health comes from smartctl instead
  export EXCLUDE_SMART="${EXCLUDE_SMART:-/dev/md1,/dev/md9,/dev/md13,/dev/md256,/dev/md322}"
  # QTS has no smartctl: use the bundled one (Entware's smartmontools + glibc,
  # see README) and force the ATA/SAT driver, the default "scsi" type returns
  # almost nothing for these SATA disks
  export PATH="$AGENT_DIR/smartctl/bin:$PATH"
  export SMART_DEVICES="${SMART_DEVICES:-/dev/sda:sat,/dev/sdb:sat,/dev/sdc:sat}"
  # QTS has no /sys/class/hwmon: read temperatures from a fake sysfs tree that
  # update_sensors() keeps filled from QNAP's getsysinfo
  export SYS_SENSORS="$FAKE_SYS"
  # Nothing to monitor here: no Docker, no systemd, no GPU, no Wi-Fi
  export DOCKER_HOST=""
  export SKIP_GPU=true
  export SKIP_SYSTEMD=true
  export SKIP_WIFI=true
  export LOG_LEVEL="${LOG_LEVEL:-info}"
}

# Prints the PID of the running supervisor loop, if any.
# The pidfile is on the data volume and survives reboots, so also check that
# the PID really belongs to our loop (the redirect order keeps the error
# message away from the console when /proc/<pid> doesn't exist).
supervisor_pid() {
  _pid=$(cat "$PID_FILE" 2> /dev/null)
  if [ -n "$_pid" ] && tr '\0' ' ' 2> /dev/null < "/proc/$_pid/cmdline" | grep -q 'beszel_init.sh supervise'; then
    echo "$_pid"
  fi
}

# True if the supervisor or an agent process is running.
is_running() {
  [ -n "$(supervisor_pid)" ] || pidof beszel-agent > /dev/null 2>&1
}

# Keep the agent log from growing forever on the data volume.
# Called before every agent launch, one old generation is kept.
rotate_log() {
  if [ -f "$AGENT_LOG" ] && [ "$(wc -c < "$AGENT_LOG")" -gt 1048576 ]; then
    mv -f "$AGENT_LOG" "$AGENT_LOG.old"
  fi
}

# Write one fake hwmon temperature: <chip dir> <chip name> <index> <label> <C>
# The files are replaced atomically so the agent never reads a half-written one.
write_temp() {
  [ -n "$5" ] || return 0
  mkdir -p "$FAKE_SYS/class/hwmon/$1"
  echo "$2" > "$FAKE_SYS/class/hwmon/$1/name"
  echo "$4" > "$FAKE_SYS/class/hwmon/$1/temp$3_label"
  echo "$(( $5 * 1000 ))" > "$FAKE_SYS/class/hwmon/$1/temp$3_input.new"
  mv -f "$FAKE_SYS/class/hwmon/$1/temp$3_input.new" "$FAKE_SYS/class/hwmon/$1/temp$3_input"
}

# Refresh the fake hwmon tree: board (hwmon0), CPU (hwmon2, only if QNAP
# reports one, the TS-431 doesn't) and the three disks (hwmon1).
# getsysinfo prints e.g. "40 C/104 F", a failed read prints nothing.
update_sensors() {
  board=$(/sbin/getsysinfo systmp 2> /dev/null | sed -n 's/^\([0-9][0-9]*\) C.*/\1/p')
  write_temp hwmon0 system 1 board "$board"
  cpu=$(/sbin/getsysinfo cputmp 2> /dev/null | sed -n 's/^\([0-9][0-9]*\) C.*/\1/p')
  write_temp hwmon2 cpu 1 package "$cpu"
  i=1
  for d in sda sdb sdc; do
    t=$(/sbin/getsysinfo hdtmp "$i" 2> /dev/null | sed -n 's/^\([0-9][0-9]*\) C.*/\1/p')
    write_temp hwmon1 disk "$i" "$d" "$t"
    i=$((i + 1))
  done
}

# The agent leaves a /tmp/beszel-sensors-* directory behind on every launch
# and /tmp is a 64 MB RAM disk. Only call this while no agent is running.
clean_tmp() {
  rm -rf /tmp/beszel-sensors-*
}

# Default action if none specified
ACTION=${1:-start}

# Log invocation for debugging
echo "$(date): Script called with parameter: '$ACTION'" >> "$BOOT_LOG"

case "$ACTION" in
  start)
    echo "$(date): Starting Beszel agent..." >> "$BOOT_LOG"

    # Don't launch a second supervisor/agent if one is already running.
    if is_running; then
      echo "$(date): Beszel agent is already running, nothing to do" >> "$BOOT_LOG"
      exit 0
    fi

    # Without the binary or the key the agent exits immediately, so the
    # supervisor would just relaunch a failing agent forever.
    if [ ! -x "$AGENT_BIN" ] || [ ! -s "$KEY_FILE" ]; then
      echo "$(date): ERROR - missing $AGENT_BIN or $KEY_FILE, not starting" >> "$BOOT_LOG"
      echo "Missing $AGENT_BIN or $KEY_FILE, see README" >&2
      exit 1
    fi

    mkdir -p "$DATA_DIR"

    # Launch the supervisor in its own session with every fd redirected, so
    # it survives the end of this script (boot hook or `ssh host ... start`)
    # and doesn't keep a non-interactive caller waiting.
    setsid "$SELF" supervise > /dev/null 2>&1 < /dev/null &

    # Wait for the agent to initialize
    sleep 3

    # Verify that the agent actually started
    if pidof beszel-agent > /dev/null 2>&1; then
      echo "$(date): Beszel agent started successfully" >> "$BOOT_LOG"
    else
      echo "$(date): WARNING - Beszel agent may not have started" >> "$BOOT_LOG"
      echo "$(date): Check $AGENT_LOG for errors" >> "$BOOT_LOG"
    fi
    ;;

  stop)
    echo "$(date): Stopping Beszel agent..." >> "$BOOT_LOG"

    # Kill the supervisor first so it can't relaunch the agent, then the agent
    sup=$(supervisor_pid)
    [ -n "$sup" ] && kill -9 "$sup"
    killall beszel-agent 2> /dev/null

    # killall only sends SIGTERM and returns. Wait for the agent to really
    # exit: a "start" right after would otherwise still see the dying process,
    # do nothing, and leave no agent running. SIGKILL it if it hangs.
    n=0
    while pidof beszel-agent > /dev/null 2>&1 && [ "$n" -lt 10 ]; do
      sleep 1
      n=$((n + 1))
    done
    killall -9 beszel-agent 2> /dev/null
    clean_tmp
    rm -rf "$FAKE_SYS"
    rm -f "$PID_FILE"

    echo "$(date): Beszel agent stopped" >> "$BOOT_LOG"
    ;;

  restart)
    echo "$(date): Restarting Beszel agent..." >> "$BOOT_LOG"
    "$0" stop
    sleep 2
    "$0" start
    ;;

  supervise)
    # Internal: the loop launched by "start". Runs the agent and relaunches it
    # 10s after it exits for any reason (crash, OOM kill, killall).
    echo "$$" > "$PID_FILE"
    agent_env
    while :; do
      clean_tmp
      rotate_log
      echo "$(date): Launching beszel-agent" >> "$BOOT_LOG"
      # The fake sensor tree must exist before the agent starts, it is
      # scanned at launch. Keep refreshing it while the agent runs.
      update_sensors
      "$AGENT_BIN" >> "$AGENT_LOG" 2>&1 &
      agent=$!
      n=0
      while kill -0 "$agent" 2> /dev/null; do
        sleep 10
        n=$((n + 1))
        [ $((n % 3)) -eq 0 ] && update_sensors
      done
      wait "$agent"
      echo "$(date): beszel-agent exited with status $?, relaunching in 10s" >> "$BOOT_LOG"
      sleep 10
    done
    ;;

  foreground)
    # Run in the foreground with output on the terminal (debugging).
    # Defaults to debug logging, Ctrl+C to quit.
    if is_running; then
      echo "Beszel agent is already running, stop it first: $0 stop" >&2
      exit 1
    fi
    LOG_LEVEL="${LOG_LEVEL:-debug}"
    agent_env
    update_sensors
    exec "$AGENT_BIN"
    ;;

  status)
    # List the PIDs before running "-v": that is a beszel-agent process too,
    # and would otherwise show up as a second, short-lived agent.
    sup=$(supervisor_pid)
    pids=$(pidof beszel-agent)
    if [ -n "$sup" ] || [ -n "$pids" ]; then
      echo "Beszel agent is running"
      "$AGENT_BIN" -v 2>&1
      echo ""
      echo "Supervisor PID: ${sup:-none}"
      echo "Agent process:"
      for pid in $pids; do
        echo "  PID $pid: $(grep -E '^(VmRSS|Threads)' "/proc/$pid/status" | tr '\n' ' ')"
      done
      [ -n "$pids" ] || echo "  none (the supervisor relaunches it)"
      echo ""
      agent_env
      echo "Listening (:${LISTEN##*:}):"
      netstat -tln 2> /dev/null | grep ":${LISTEN##*:} " || echo "  not listening"
    else
      echo "Beszel agent is not running"
      exit 1
    fi
    ;;

  log)
    # Follow the agent log
    echo "Following Beszel agent log (Ctrl+C to exit)..."
    tail -f "$AGENT_LOG"
    ;;

  bootlog)
    # Show boot log
    cat "$BOOT_LOG"
    ;;

  *)
    echo "Usage: $0 {start|stop|restart|status|log|bootlog|foreground}"
    echo ""
    echo "Commands:"
    echo "  start      - Start Beszel agent (supervised)"
    echo "  stop       - Stop Beszel agent"
    echo "  restart    - Restart Beszel agent"
    echo "  status     - Show Beszel agent status"
    echo "  log        - Follow Beszel agent log"
    echo "  bootlog    - Show boot/startup log"
    echo "  foreground - Run in the foreground with debug logging"
    exit 1
    ;;
esac

exit 0
