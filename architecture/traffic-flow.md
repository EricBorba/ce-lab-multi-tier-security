# Traffic Flow Documentation

## Overview

Traffic in this architecture flows strictly top-down through defined tiers. No tier can skip a layer or communicate laterally with a peer at the same tier.

```
Internet
   │
   │  HTTP/HTTPS (80/443)
   ▼
┌─────────────────┐
│   Web Tier      │  ← sg-web-tier
│  (EC2 / ALB)    │
└────────┬────────┘
         │  Port 8080 (internal only)
         ▼
┌─────────────────┐
│   App Tier      │  ← sg-app-tier
│  (EC2 backend)  │
└────────┬────────┘
         │  Port 3306 / 5432 (internal only)
         ▼
┌─────────────────┐
│  Database Tier  │  ← sg-database-tier
│  (RDS / EC2 DB) │
└─────────────────┘

     ──── Admin SSH Path ────

Your IP /32
   │
   │  Port 22
   ▼
┌─────────────────┐
│   Bastion Host  │  ← sg-bastion
│  (Jump server)  │
└──┬──────────┬───┘
   │ Port 22  │ Port 22
   ▼          ▼
Web Tier    App Tier
```

---

## Flow 1 — Public User Web Request

| Step | Source | Destination | Port | Protocol |
|------|--------|-------------|------|----------|
| 1 | Internet (`0.0.0.0/0`) | Web Tier EC2 / ALB | 80 or 443 | TCP |
| 2 | Web Tier (`sg-web-tier`) | App Tier EC2 | 8080 | TCP |
| 3 | App Tier (`sg-app-tier`) | Database EC2 / RDS | 3306 or 5432 | TCP |
| 4 | Database | App Tier (response) | ephemeral | TCP |
| 5 | App Tier (response) | Web Tier | ephemeral | TCP |
| 6 | Web Tier (response) | Internet | ephemeral | TCP |

**Notes:**
- Steps 4–6 are return traffic handled automatically by stateful security group tracking.
- The web tier never contacts the database; it only speaks to the app tier.

---

## Flow 2 — Administrator SSH Access

| Step | Source | Destination | Port |
|------|--------|-------------|------|
| 1 | Admin workstation (`YOUR_IP/32`) | Bastion Host | 22 |
| 2 | Bastion (`sg-bastion`) | Web Tier EC2 | 22 |
| OR 2 | Bastion (`sg-bastion`) | App Tier EC2 | 22 |
| OR 2 | Bastion (`sg-bastion`) | Database EC2 | 22 |

**Notes:**
- The administrator SSHs to the bastion first, then performs a second SSH hop to the target instance.
- The bastion cannot be reached on port 22 from any IP other than `YOUR_IP/32`.
- There is no direct SSH path from the internet to web, app, or database instances.

---

## Flow 3 — Software Updates (Outbound)

All tiers except the bastion are permitted outbound `443` to `0.0.0.0/0` to allow:
- `apt` / `yum` package manager updates via HTTPS
- AWS Systems Manager Agent (SSM) communication
- CloudWatch agent metric/log publishing

This outbound rule should be scoped to specific AWS service IP ranges in a hardened production environment.

---

## Blocked Traffic (Verification Points)

The following flows are explicitly **not permitted** and should be verified during testing:

| Blocked Flow | Reason |
|---|---|
| Internet → App Tier on any port | `sg-app-tier` has no inbound rule from `0.0.0.0/0` |
| Internet → Database Tier on any port | `sg-database-tier` has no inbound rule from `0.0.0.0/0` |
| Web Tier → Database Tier on DB port | `sg-web-tier` has no outbound rule to `sg-database-tier` |
| Internet → Bastion on any port except 22 | `sg-bastion` only opens port 22 inbound |
| Direct SSH from internet to any non-bastion host | All non-bastion SGs accept SSH from `sg-bastion` only |
