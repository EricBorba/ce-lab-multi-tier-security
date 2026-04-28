#!/usr/bin/env bash
# =============================================================================
# test-commands.sh
# Multi-Tier Security Group — Connectivity Test Suite
# =============================================================================

# ─── CONFIGURATION — update these before running ─────────────────────────────
KEY_FILE="$HOME/.ssh/my-third-key.pem"
SSH_USER="ec2-user"

BASTION_PUBLIC_IP="3.66.168.80"
WEB_PUBLIC_IP="52.58.25.75"
APP_PUBLIC_IP="3.76.31.121"
DB_PUBLIC_IP="3.73.144.252"

WEB_PRIVATE_IP="172.31.38.32"
APP_PRIVATE_IP="172.31.46.213"
DB_PRIVATE_IP="172.31.45.59"
# ─────────────────────────────────────────────────────────────────────────────

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'
PASS=0; FAIL=0

result() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo -e "${GREEN}[PASS]${NC} $label"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}[FAIL]${NC} $label"
    FAIL=$((FAIL + 1))
  fi
}

# SSH test — prints server output directly, sets global TEST_RESULT
ssh_test() {
  local target="$1" cmd="$2"
  echo -e "${CYAN}   Server response:${NC}"
  output=$(ssh -i "$KEY_FILE" \
      -o ConnectTimeout=8 -o StrictHostKeyChecking=no -o BatchMode=yes \
      "$target" "$cmd" 2>&1)
  echo "$output" | sed 's/^/   | /'
  echo "$output" | grep -q "connected" && TEST_RESULT="pass" || TEST_RESULT="fail"
}

# SSH hop test via bastion — prints server output, sets global TEST_RESULT
ssh_hop_test() {
  local private_target="$1" cmd="$2"
  echo -e "${CYAN}   Server response:${NC}"
  output=$(ssh -i "$KEY_FILE" \
      -o ConnectTimeout=8 -o StrictHostKeyChecking=no -o BatchMode=yes \
      -o ProxyCommand="ssh -i $KEY_FILE -o StrictHostKeyChecking=no -o BatchMode=yes -W %h:%p $SSH_USER@$BASTION_PUBLIC_IP" \
      "$SSH_USER@$private_target" "$cmd" 2>&1)
  echo "$output" | sed 's/^/   | /'
  echo "$output" | grep -q "connected\|open" && TEST_RESULT="pass" || TEST_RESULT="fail"
}

YOUR_IP=$(curl -s --max-time 5 https://checkip.amazonaws.com || echo "unknown")

echo "============================================================"
echo "  Multi-Tier Security Group Test Suite"
echo "  Your public IP: $YOUR_IP"
echo "  $(date)"
echo "============================================================"
echo ""

# =============================================================================
# TEST 1 — SSH from internet to bastion (should SUCCEED)
# =============================================================================
echo "── TEST 1: SSH from internet → Bastion ─────────────────────"
ssh_test "$SSH_USER@$BASTION_PUBLIC_IP" "echo connected && hostname && uptime"
result "SSH to bastion — should SUCCEED" "pass" "$TEST_RESULT"
echo ""

# =============================================================================
# TEST 2 — Direct SSH from internet to web tier (should be BLOCKED)
# =============================================================================
echo "── TEST 2: Direct SSH from internet → Web tier ─────────────"
ssh_test "$SSH_USER@$WEB_PUBLIC_IP" "echo connected && hostname"
result "Direct SSH to web tier from internet — should be BLOCKED" "fail" "$TEST_RESULT"
echo ""

# =============================================================================
# TEST 3 — HTTP from internet to web tier (should SUCCEED)
# =============================================================================
echo "── TEST 3: HTTP from internet → Web tier ───────────────────"
echo -e "${CYAN}   Server response:${NC}"
http_output=$(curl -s --max-time 8 -o - -w "\nHTTP status: %{http_code}" "http://$WEB_PUBLIC_IP" 2>&1)
echo "$http_output" | sed 's/^/   | /'
echo "$http_output" | grep -qv "HTTP status: 000" && TEST_RESULT="pass" || TEST_RESULT="fail"
result "HTTP (port 80) to web tier — should SUCCEED" "pass" "$TEST_RESULT"
echo ""

# =============================================================================
# TEST 4 — Direct SSH from internet to app tier (should be BLOCKED)
# =============================================================================
echo "── TEST 4: Direct SSH from internet → App tier ─────────────"
ssh_test "$SSH_USER@$APP_PUBLIC_IP" "echo connected && hostname"
result "Direct SSH to app tier from internet — should be BLOCKED" "fail" "$TEST_RESULT"
echo ""

# =============================================================================
# TEST 5 — Direct SSH from internet to database tier (should be BLOCKED)
# =============================================================================
echo "── TEST 5: Direct SSH from internet → Database ─────────────"
ssh_test "$SSH_USER@$DB_PUBLIC_IP" "echo connected && hostname"
result "Direct SSH to database from internet — should be BLOCKED" "fail" "$TEST_RESULT"
echo ""

# =============================================================================
# TEST 6 — SSH hop: bastion → web tier (should SUCCEED)
# =============================================================================
echo "── TEST 6: SSH hop — bastion → web tier ────────────────────"
ssh_hop_test "$WEB_PRIVATE_IP" "echo connected && hostname && uptime"
result "SSH via bastion to web tier — should SUCCEED" "pass" "$TEST_RESULT"
echo ""

# =============================================================================
# TEST 7 — SSH hop: bastion → app tier (should SUCCEED)
# =============================================================================
echo "── TEST 7: SSH hop — bastion → app tier ────────────────────"
ssh_hop_test "$APP_PRIVATE_IP" "echo connected && hostname && uptime"
result "SSH via bastion to app tier — should SUCCEED" "pass" "$TEST_RESULT"
echo ""

# =============================================================================
# TEST 8 — From web tier: reach app tier on port 8080 (should SUCCEED)
# =============================================================================
echo "── TEST 8: Web tier → App tier port 8080 ───────────────────"
ssh_hop_test "$WEB_PRIVATE_IP" "timeout 5 bash -c 'echo > /dev/tcp/$APP_PRIVATE_IP/8080' && echo open || echo closed"
result "Web tier → app tier port 8080 — should SUCCEED" "pass" "$TEST_RESULT"
echo ""

# =============================================================================
# TEST 9 — From web tier: reach database port 3306 (should be BLOCKED)
# =============================================================================
echo "── TEST 9: Web tier → Database port 3306 ───────────────────"
ssh_hop_test "$WEB_PRIVATE_IP" "timeout 5 bash -c 'echo > /dev/tcp/$DB_PRIVATE_IP/3306' && echo open || echo closed"
result "Web tier → database port 3306 — should be BLOCKED" "fail" "$TEST_RESULT"
echo ""

# =============================================================================
# TEST 10 — From app tier: reach database port 3306 (should SUCCEED)
# =============================================================================
echo "── TEST 10: App tier → Database port 3306 ──────────────────"
ssh_hop_test "$APP_PRIVATE_IP" "timeout 5 bash -c 'echo > /dev/tcp/$DB_PRIVATE_IP/3306' && echo open || echo closed"
result "App tier → database port 3306 — should SUCCEED" "pass" "$TEST_RESULT"
echo ""

# =============================================================================
# SUMMARY
# =============================================================================
echo "============================================================"
echo -e "  Results: ${GREEN}${PASS} passed${NC}  |  ${RED}${FAIL} failed${NC}"
echo "============================================================"
[ "$FAIL" -eq 0 ] && echo -e "${GREEN}All tests passed!${NC}" || echo "Review any failed tests above."
