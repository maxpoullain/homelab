#!/bin/bash

echo "=== ZFS Scrub Status ==="
echo ""

# Check last scrub time and results
echo "Fast pool scrub status:"
zpool status fast | grep -A 10 "scan:"

echo ""
echo "Tank pool scrub status:"
zpool status tank | grep -A 10 "scan:"

echo ""

# Check for any errors
echo "Error summary:"
zpool status fast tank | grep -E "(errors|DEGRADED|FAULTED)" || echo "  No errors found ✓"

echo ""

# Scrub history
echo "Recent scrub history:"
zpool history fast tank | grep scrub | tail -10