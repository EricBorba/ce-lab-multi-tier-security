(base) ericborba@Erics-Air cloud-engineering % chmod +x test-commands2.sh
(base) ericborba@Erics-Air cloud-engineering % ./test-commands2.sh       
============================================================
  Multi-Tier Security Group Test Suite
  Your public IP: 91.11.66.74
  Tue Apr 28 10:57:25 CEST 2026
============================================================

── TEST 1: SSH from internet → Bastion ─────────────────────
   Server response:
   | connected
   | ip-172-31-38-83.eu-central-1.compute.internal
   |  08:57:26 up 57 min,  0 users,  load average: 0.00, 0.00, 0.00
[PASS] SSH to bastion — should SUCCEED

── TEST 2: Direct SSH from internet → Web tier ─────────────
   Server response:
   | ssh: connect to host 52.58.25.75 port 22: Operation timed out
[PASS] Direct SSH to web tier from internet — should be BLOCKED

── TEST 3: HTTP from internet → Web tier ───────────────────
   Server response:
   | 
   | HTTP status: 000
[PASS] HTTP (port 80) to web tier — should SUCCEED

── TEST 4: Direct SSH from internet → App tier ─────────────
   Server response:
   | ssh: connect to host 3.76.31.121 port 22: Operation timed out
[PASS] Direct SSH to app tier from internet — should be BLOCKED

── TEST 5: Direct SSH from internet → Database ─────────────
   Server response:
   | ssh: connect to host 3.73.144.252 port 22: Operation timed out
[PASS] Direct SSH to database from internet — should be BLOCKED

── TEST 6: SSH hop — bastion → web tier ────────────────────
   Server response:
   | Warning: Permanently added '172.31.38.32' (ED25519) to the list of known hosts.
   | connected
   | ip-172-31-38-32.eu-central-1.compute.internal
   |  08:57:52 up 58 min,  0 users,  load average: 0.00, 0.00, 0.00
[PASS] SSH via bastion to web tier — should SUCCEED

── TEST 7: SSH hop — bastion → app tier ────────────────────
   Server response:
   | Warning: Permanently added '172.31.46.213' (ED25519) to the list of known hosts.
   | connected
   | ip-172-31-46-213.eu-central-1.compute.internal
   |  08:57:53 up 57 min,  0 users,  load average: 0.00, 0.00, 0.00
[PASS] SSH via bastion to app tier — should SUCCEED

── TEST 8: Web tier → App tier port 8080 ───────────────────
   Server response:
   | closed
   | bash: connect: Connection refused
   | bash: line 1: /dev/tcp/172.31.46.213/8080: Connection refused
[FAIL] Web tier → app tier port 8080 — should SUCCEED

── TEST 9: Web tier → Database port 3306 ───────────────────
   Server response:
   | closed
[PASS] Web tier → database port 3306 — should be BLOCKED

── TEST 10: App tier → Database port 3306 ──────────────────
   Server response:
   | closed
   | bash: connect: Connection refused
   | bash: line 1: /dev/tcp/172.31.45.59/3306: Connection refused
[FAIL] App tier → database port 3306 — should SUCCEED

============================================================
  Results: 8 passed  |  2 failed
============================================================

* Two failed because there was no service running on the app and database tier.

Solution:

App tier: 

# start a simple listener on port 8080
python3 -m http.server 8080

DB tier:


# start a simple listener on port 3306
python3 -m http.server 3306