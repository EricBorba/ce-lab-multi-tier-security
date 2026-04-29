# Lab M2.03 — Multi-Tier Security Groups
**Cloud Engineering Bootcamp | Week 2 — Core Services & Secure Deployment**

---

## Security Design Philosophy

This lab implements a **3-tier + bastion architecture** grounded in two principles:

**Defense in depth** — rather than relying on a single perimeter, each tier has its own security group with rules that assume every adjacent tier could be compromised. If the web tier is breached, the attacker still cannot reach the database.

**Least privilege** — every rule permits the minimum necessary access. Ports, protocols, and source/destination addresses are as narrow as possible. When two tiers need to communicate, the rule uses a security group reference (not a CIDR) so the trust boundary is membership-based, not IP-based.

---

## Architecture

```
Internet
   │  HTTP/HTTPS
   ▼
[Web Tier]  ──8080──▶  [App Tier]  ──3306──▶  [Database Tier]
   ▲                       ▲                        ▲
   │ SSH                   │ SSH                    │ SSH
   └───────────────────────┴────────────────────────┘
                     [Bastion Host]
                           ▲
                     SSH (your IP only)
```

---

## How Each Tier Protects the Next

| Tier | Protected by | Cannot be reached from |
|------|-------------|------------------------|
| Web | `sg-web-tier` | Direct SSH from internet; any port not 80/443/22-from-bastion |
| App | `sg-app-tier` | Internet on any port; web tier on anything except 8080 |
| Database | `sg-database-tier` | Internet on any port; web tier on any port; non-DB ports |
| Bastion | `sg-bastion` | Any IP except your `/32` on SSH; any port except 22 |

---

## Repository Structure

```
ce-lab-multi-tier-security/
├── SOLUTION.md                        ← This file
├── architecture/
│   ├── architecture-diagram.png     ← AWS Console / draw.io diagram
│   ├── security-groups-design.md    ← Design decisions and rationale
│   └── traffic-flow.md              ← How traffic moves through each tier
├── security-groups/
│   ├── sg-bastion-rules.txt
│   ├── sg-web-tier-rules.txt
│   ├── sg-app-tier-rules.txt
│   └── sg-database-rules.txt
├── tests/
│   ├── security-test-results.md     ← Completed — all 6 tests passed (2026-04-29)
│   └── test-commands.sh             ← Parameterised connectivity test script
└── screenshots/
    ├── 01-security-groups-list.png
    ├── 02-web-tier-rules.png
    ├── 03-traffic-flow-test.png
    └── 04-architecture-console.png
```

---

## Security Group Rule Summary

### sg-bastion
| Direction | Port | Source / Destination | Reason |
|-----------|------|---------------------|--------|
| Inbound | 22 | `YOUR_IP/32` | Your workstation only |
| Outbound | 22 | `sg-web-tier` | Jump to web instances |
| Outbound | 22 | `sg-app-tier` | Jump to app instances |
| Outbound | 22 | `sg-database-tier` | Emergency DBA access |

### sg-web-tier
| Direction | Port | Source / Destination | Reason |
|-----------|------|---------------------|--------|
| Inbound | 80 | `0.0.0.0/0` | Public HTTP |
| Inbound | 443 | `0.0.0.0/0` | Public HTTPS |
| Inbound | 22 | `sg-bastion` | Admin SSH via jump host |
| Outbound | 8080 | `sg-app-tier` | Forward app requests |
| Outbound | 443 | `0.0.0.0/0` | Package updates |

### sg-app-tier
| Direction | Port | Source / Destination | Reason |
|-----------|------|---------------------|--------|
| Inbound | 8080 | `sg-web-tier` | App requests from web tier only |
| Inbound | 22 | `sg-bastion` | Admin SSH via jump host |
| Outbound | 3306 | `sg-database-tier` | MySQL queries |
| Outbound | 443 | `0.0.0.0/0` | Package updates |

### sg-database-tier
| Direction | Port | Source / Destination | Reason |
|-----------|------|---------------------|--------|
| Inbound | 3306 | `sg-app-tier` | DB connections from app tier only |
| Inbound | 22 | `sg-bastion` | Emergency DBA access |
| Outbound | 443 | `0.0.0.0/0` | Package updates |

---

## Running the Tests

```bash
# 1. Make the script executable
chmod +x tests/test-commands.sh

# 2. Edit the variables at the top of the file:
#    KEY, BASTION_PUBLIC_IP, WEB_PUBLIC_IP, WEB_PRIVATE_IP, APP_PRIVATE_IP, DB_PRIVATE_IP

# 3. Run all tests
./tests/test-commands.sh

# 4. Results are recorded in tests/security-test-results.md
```

### Quick Manual Tests

```bash
# Test: Web tier reachable from internet
curl http://<WEB_PUBLIC_IP>
# Expected: "Hello from App Tier"

# Test: SSH to web tier via bastion (ProxyCommand — recommended)
ssh -i ~/.ssh/my-third-key.pem \
  -o ProxyCommand="ssh -i ~/.ssh/my-third-key.pem -W %h:%p ec2-user@<BASTION_PUBLIC_IP>" \
  ec2-user@<WEB_PRIVATE_IP>

# Test: Direct SSH to web tier from internet (should timeout)
ssh -i ~/.ssh/your-key.pem ec2-user@<WEB_PUBLIC_IP>

# Test (from web tier): reach app tier on port 8080
nc -zv <APP_PRIVATE_IP> 8080

# Test (from app tier): reach database on port 3306
nc -zv <DB_PRIVATE_IP> 3306

# Test (from web tier — should FAIL): reach database directly
nc -zv <DB_PRIVATE_IP> 3306
```

> **Note on SSH access:** Direct SSH from the bastion to a private instance (without key forwarding) will return `Permission denied`. The recommended method is to use `ProxyCommand` from your local machine, which tunnels through the bastion while keeping the private key local. See `tests/test-commands.sh` for the exact syntax.

---

## Test Results Summary

Tests were executed on **2026-04-29** against the deployed infrastructure.

| Test | Description | Expected | Result |
|------|-------------|----------|--------|
| 1 | HTTP to web tier from internet | ✅ Allow | ✅ PASS |
| 2 | SSH via bastion (no key forwarding) | ❌ Deny | ✅ PASS |
| 3 | Direct SSH to web tier from internet | ❌ Deny | ✅ PASS |
| 4 | App tier port 8080 from web tier | ✅ Allow | ✅ PASS |
| 5 | DB tier port 3306 from app tier | ✅ Allow | ✅ PASS |
| 6 | DB tier port 3306 from web tier | ❌ Deny | ✅ PASS |

**All 6 tests passed.** Full details, commands, and raw output are in `tests/security-test-results.md`.

### Actual IP Mapping (this lab run)

| Tier | Public IP | Private IP |
|------|-----------|------------|
| Bastion | 18.156.3.223 | — |
| Web | 54.93.227.55 | 172.31.47.23 |
| App | — | 172.31.41.53 |
| DB | — | 172.31.36.157 |

---

## Key Security Concepts Demonstrated

**Security Group References** — instead of using IP addresses like `10.0.1.0/24` in rules, each tier references the security group ID of the adjacent tier (`sg-0abc123`). This means:
- Rules stay accurate as Auto Scaling adds/removes instances (IPs change, SG membership doesn't)
- There is no way for an instance outside the SG to spoof access

**Stateful Inspection** — AWS Security Groups are stateful. Return traffic (e.g., the database responding to the app tier) is automatically allowed without needing an explicit inbound rule, because the connection was initiated from the permitted source.

**No Bidirectional Rules Needed** — because of statefulness, you only define rules in the direction of initiation. The app tier has an outbound rule to the DB; no inbound rule on the app tier is needed for DB response traffic.
