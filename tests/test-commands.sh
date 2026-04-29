#!/bin/bash
# =============================================================================
# Security Test Commands — 3-Tier AWS Architecture
# =============================================================================
# Replace the variables below with your actual IPs before running.
# =============================================================================

BASTION_PUBLIC_IP="18.156.3.223"
WEB_PUBLIC_IP="54.93.227.55"
WEB_PRIVATE_IP="172.31.47.23"
APP_PRIVATE_IP="172.31.41.53"
DB_PRIVATE_IP="172.31.36.157"
KEY="~/.ssh/my-third-key.pem"

# -----------------------------------------------------------------------------
# TEST 1: Web tier reachable from internet (should succeed)
# -----------------------------------------------------------------------------
echo "=== TEST 1: HTTP to web tier from internet ==="
curl http://$WEB_PUBLIC_IP
# Expected: "Hello from App Tier"

# -----------------------------------------------------------------------------
# TEST 2: SSH via bastion (with ProxyCommand — recommended method)
# -----------------------------------------------------------------------------
echo ""
echo "=== TEST 2: SSH to web instance via bastion (ProxyCommand) ==="
ssh -i $KEY \
  -o ProxyCommand="ssh -i $KEY -W %h:%p ec2-user@$BASTION_PUBLIC_IP" \
  ec2-user@$WEB_PRIVATE_IP

# -----------------------------------------------------------------------------
# TEST 3: Direct SSH to web tier from internet (should timeout/fail)
# -----------------------------------------------------------------------------
echo ""
echo "=== TEST 3: Direct SSH to web tier — should timeout ==="
ssh -i $KEY ec2-user@$WEB_PUBLIC_IP
# Expected: Operation timed out

# -----------------------------------------------------------------------------
# TEST 4: App tier reachable from web tier on port 8080 (should succeed)
# -----------------------------------------------------------------------------
echo ""
echo "=== TEST 4: Port 8080 reachable from web tier to app tier ==="
ssh -i $KEY \
  -o ProxyCommand="ssh -i $KEY -W %h:%p ec2-user@$BASTION_PUBLIC_IP" \
  ec2-user@$WEB_PRIVATE_IP \
  "nc -zv $APP_PRIVATE_IP 8080"
# Expected: Ncat: Connected to <app-ip>:8080

# -----------------------------------------------------------------------------
# TEST 5: DB tier reachable from app tier on port 3306 (should succeed)
# -----------------------------------------------------------------------------
echo ""
echo "=== TEST 5: Port 3306 reachable from app tier to DB tier ==="
ssh -i $KEY \
  -o ProxyCommand="ssh -i $KEY -W %h:%p ec2-user@$BASTION_PUBLIC_IP" \
  ec2-user@$APP_PRIVATE_IP \
  "nc -zv $DB_PRIVATE_IP 3306"
# Expected: Ncat: Connected to <db-ip>:3306

# -----------------------------------------------------------------------------
# TEST 6: DB tier NOT reachable from web tier (should timeout)
# -----------------------------------------------------------------------------
echo ""
echo "=== TEST 6: Port 3306 from web tier to DB tier — should timeout ==="
ssh -i $KEY \
  -o ProxyCommand="ssh -i $KEY -W %h:%p ec2-user@$BASTION_PUBLIC_IP" \
  ec2-user@$WEB_PRIVATE_IP \
  "nc -zv $DB_PRIVATE_IP 3306"
# Expected: Ncat: TIMEOUT



# --- End-to-end test ---
curl http://$WEB_PUBLIC_IP
# Expected: "Hello from App Tier"
