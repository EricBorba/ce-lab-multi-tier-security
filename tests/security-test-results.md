# Security Test Results

**Date:** 2026-04-29  
**Environment:** AWS 3-Tier Architecture (Web / App / DB)  
**Tester:** Eric Borba

---

## Infrastructure Overview

| Tier | Instance | IP (Public) | IP (Private) |
|------|----------|-------------|--------------|
| Bastion | — | 18.156.3.223 | — |
| Web | — | 54.93.227.55 | 172.31.47.23 |
| App | — | — | 172.31.41.53 |
| DB | — | — | 172.31.36.157 |

---

## Test 1 — Web Tier Reachable from Internet (HTTP)

**Command:**
```bash
curl http://54.93.227.55
```

**Result:** ✅ PASS  
**Response:** `Hello from App Tier`  

The web tier is publicly reachable on port 80. Nginx successfully proxied the request through to the app tier, which responded correctly.

---

## Test 2 — SSH Access via Bastion Host

**Command:**
```bash
# Step 1: SSH into bastion
ssh -i my-third-key.pem ec2-user@18.156.3.223

# Step 2: From bastion, attempt SSH into web instance (private IP)
ssh ec2-user@172.31.47.23
```

**Result:** ❌ FAIL (as expected — no key forwarded)  
**Response:** `Permission denied (publickey,gssapi-keyex,gssapi-with-mic)`

Direct SSH from bastion to web instance failed because the private key was not forwarded to the bastion session. This is the expected and secure behavior — the bastion itself does not hold the private key.

PS: However, it is possible to be done by using the following command:

```bash 
ssh -i ~/.ssh/my-third-key.pem \
  -o ProxyCommand="ssh -i ~/.ssh/my-third-key.pem -W %h:%p ec2-user@18.156.3.223" \
  ec2-user@172.31.47.23
```

**Workaround used:** SSH ProxyCommand (see Test 3).

---

## Test 3 — Direct SSH to Web Instance from Internet (Should Fail)

**Command:**
```bash
ssh -i my-third-key.pem ec2-user@54.93.227.55
```

**Result:** ✅ PASS (correctly blocked)  
**Response:** `ssh: connect to host 54.93.227.55 port 22: Operation timed out`

Port 22 is not open on the web tier's security group for public internet access. The connection timed out, confirming that direct SSH from outside is correctly blocked.

---

## Test 4 — App Tier Reachable from Web Tier (Port 8080)

**Access method:** SSH via ProxyCommand through bastion → web instance  
**Command:**
```bash
# Connect to web instance via bastion
ssh -i ~/.ssh/my-third-key.pem \
  -o ProxyCommand="ssh -i ~/.ssh/my-third-key.pem -W %h:%p ec2-user@18.156.3.223" \
  ec2-user@172.31.47.23

# From web instance, test connectivity to app tier
nc -zv 172.31.41.53 8080
```

**Result:** ✅ PASS  
**Response:**
```
Ncat: Version 7.93 ( https://nmap.org/ncat )
Ncat: Connected to 172.31.41.53:8080.
Ncat: 0 bytes sent, 0 bytes received in 0.01 seconds.
```

The web tier can reach the app tier on port 8080, as required for the reverse proxy to function.

---

## Test 5 — Database Tier Reachable from App Tier (Port 3306)

**Access method:** SSH via ProxyCommand through bastion → app instance  
**Command:**
```bash
# Connect to app instance via bastion
ssh -i ~/.ssh/my-third-key.pem \
  -o ProxyCommand="ssh -i ~/.ssh/my-third-key.pem -W %h:%p ec2-user@18.156.3.223" \
  ec2-user@172.31.41.53

# From app instance, test connectivity to DB tier
nc -zv 172.31.36.157 3306
```

**Result:** ✅ PASS  
**Response:**
```
Ncat: Version 7.93 ( https://nmap.org/ncat )
Ncat: Connected to 172.31.36.157:3306.
Ncat: 0 bytes sent, 0 bytes received in 0.01 seconds.
```

The app tier can reach the database tier on port 3306 (MySQL), as required.

---

## Test 6 — Database Tier NOT Reachable from Web Tier (Should Fail)

**Access method:** SSH via ProxyCommand through bastion → web instance  
**Command:**
```bash
# Connect to web instance via bastion
ssh -i ~/.ssh/my-third-key.pem \
  -o ProxyCommand="ssh -i ~/.ssh/my-third-key.pem -W %h:%p ec2-user@18.156.3.223" \
  ec2-user@172.31.47.23

# From web instance, attempt to reach DB tier directly
nc -zv 172.31.36.157 3306
```

**Result:** ✅ PASS (correctly blocked)  
**Response:** `Ncat: TIMEOUT.`

The web tier cannot directly reach the database tier on port 3306. The security group on the DB tier only allows inbound traffic from the app tier, not the web tier. Network segmentation is working correctly.

---

## Summary

| Test | Description | Expected | Result |
|------|-------------|----------|--------|
| 1 | HTTP to web tier from internet | ✅ Allow | ✅ PASS |
| 2 | SSH via bastion (no key forwarding) | ❌ Deny | ✅ PASS |
| 3 | Direct SSH to web tier from internet | ❌ Deny | ✅ PASS |
| 4 | App tier port 8080 from web tier | ✅ Allow | ✅ PASS |
| 5 | DB tier port 3306 from app tier | ✅ Allow | ✅ PASS |
| 6 | DB tier port 3306 from web tier | ❌ Deny | ✅ PASS |

**All 6 tests passed.** Security group rules are correctly enforcing network segmentation across all three tiers.
