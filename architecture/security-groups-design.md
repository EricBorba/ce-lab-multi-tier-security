# Security Groups Design — Multi-Tier Architecture

## Design Philosophy

This architecture follows **defense-in-depth**: each tier is isolated and can only communicate with adjacent tiers using the minimum required ports. No tier can bypass layers to reach a non-adjacent tier.

The core principles applied:
- **Least Privilege** – every rule allows only the exact port, protocol, and source required
- **Security Group References** – tiers reference each other's SG IDs instead of IP ranges, so rules stay valid even as instances scale or IPs change
- **No Direct Internet Access** – only the web tier and bastion are reachable from the internet; all other tiers are fully private

---

## Tier-by-Tier Design Decisions

### Bastion Security Group (`sg-bastion`)

**Purpose:** Provides the single controlled entry point into the private network for administrative SSH access.

**Design decisions:**
- Inbound SSH (`port 22`) is restricted to `YOUR_IP/32` only — no other source can initiate a connection to the bastion. Using `/32` (single IP) rather than a CIDR range minimises the attack surface.
- Outbound SSH is permitted only to `sg-web-tier`, `sg-app-tier`, and `sg-db-tier`.
- All other outbound traffic is denied by default.

**Why no broad outbound rules?** The bastion is purely a jump host. It should never browse the internet or call external APIs; limiting outbound traffic prevents the bastion from being used as a pivot if compromised.

---

### Web Tier Security Group (`sg-web-tier`)

**Purpose:** Terminates public HTTP/HTTPS traffic and forwards application requests to the app tier.

**Design decisions:**
- Inbound `80` and `443` from `0.0.0.0/0` — web servers must be publicly reachable.
- Inbound `22` from `sg-bastion` only — administrators SSH through the bastion, never directly from the internet.
- Outbound to `sg-app-tier` on port `8080` only — the web tier cannot reach the database tier under any circumstances. This is the most important cross-tier restriction in the design.
- Outbound `443` to `0.0.0.0/0` is allowed for package updates and external API calls (e.g., certificate renewals, telemetry agents). This should be tightened to specific CIDR ranges in a production environment.

---

### Application Tier Security Group (`sg-app-tier`)

**Purpose:** Runs backend business logic; accepts requests only from the web tier.

**Design decisions:**
- Inbound `8080` from `sg-web-tier` only — no other source can call the app tier directly, not even from the internet.
- Inbound `22` from `sg-bastion` only.
- Outbound `3306` (MySQL) or `5432` (PostgreSQL) to `sg-database-tier` only — the app tier is the single authorised client of the database.
- Outbound `443` to `0.0.0.0/0` for updates (same caveat as web tier).

---

### Database Tier Security Group (`sg-database-tier`)

**Purpose:** Protects the most sensitive data tier; accepts connections from the app tier only.

**Design decisions:**
- Inbound DB port (`3306`/`5432`) from `sg-app-tier` only — the strictest rule in the design. No web server, bastion, or external source can connect to the database.
- Inbound `22` from `sg-bastion` for emergency DBA access.
- Outbound `443` to `0.0.0.0/0` is permitted for OS/patch updates only.
- No inbound rule for `0.0.0.0/0` on any port.

---

## Security Group References vs. CIDR Ranges

| Approach | When to use |
|---|---|
| SG Reference (e.g., `sg-0abc123`) | Communication between tiers within the same VPC — always preferred |
| Specific CIDR `/32` | A known, fixed external IP (e.g., your workstation for bastion SSH) |
| Broad CIDR `0.0.0.0/0` | Public-facing services only (web tier HTTP/HTTPS inbound, general outbound for updates) |

Using SG references instead of private IP ranges means rules remain accurate as Auto Scaling adds or removes instances. The security group membership defines the trust boundary, not the IP address.

---

## What This Design Prevents

| Attack vector | Mitigation |
|---|---|
| Direct SSH from internet to web/app/DB | Bastion is the only SSH entry point |
| Web tier reaching database directly | No outbound rule from `sg-web-tier` to DB port |
| Database reachable from internet | No inbound `0.0.0.0/0` on `sg-database-tier` |
| Lateral movement from compromised web server | App and DB tiers reject connections not sourced from the correct upstream SG |
| Bastion used as general internet gateway | Outbound restricted to SSH toward specific tier SGs |
