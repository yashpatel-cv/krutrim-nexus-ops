# Krutrim Nexus Ops - Minimalist Cluster Orchestration

- [x] **Phase 1: Architecture & Restructuring**
    - [x] Rename project to `krutrim-nexus-ops` <!-- id: 0 -->
    - [x] Refactor `install.sh` for Role-based Install (Manager/Worker) <!-- id: 1 -->
    - [x] Verify & Fix Directory Structure <!-- id: 2 -->
    - [x] Initialize Git Repo & Commit <!-- id: 16 -->

- [x] **Phase 2: Core Infrastructure (Tier 1)**
    - [x] Firewall (`nftables.conf`) <!-- id: 3 -->
    - [x] Kernel Hardening (`99-hardening.conf`) <!-- id: 4 -->
    - [x] DNS (`unbound.conf`) <!-- id: 5 -->
    - [x] Privacy (`torrc`, `i2pd.conf`) <!-- id: 6 -->

- [x] **Phase 3: Minimalist Service Stack (Luke Smith-style)**
    - [x] Mail: `emailwiz`-style Postfix/Dovecot (Flat files, no SQL) <!-- id: 7 -->
    - [x] Storage: SFTP + Nginx Autoindex (No MinIO bloat) <!-- id: 8 -->
    - [x] Web/LB: Caddy (Simple reverse proxy) <!-- id: 9 -->
    - [x] DB: PostgreSQL (Standard, minimal tuning) <!-- id: 10 -->

- [x] **Phase 4: Cluster Manager (The "Nexus")**
    - [x] `nexus.py`: Simple SSH loop wrapper (No heavy deps) <!-- id: 11 -->
    - [x] `nexus create-user`: Helper for Mail/Storage users <!-- id: 17 -->
    - [x] **[NEW]** Interactive Installer (`install.sh`) <!-- id: 18 -->
    - [x] **[NEW]** Monitoring Dashboard (`nexus monitor`) <!-- id: 19 -->

- [x] **Phase 5: Verification & Docs**
    - [x] Update `verify.sh` <!-- id: 13 -->
    - [x] Update `README.md` with Detailed Q&A <!-- id: 14 -->
    - [x] **[NEW]** Document HA & Monitoring <!-- id: 20 -->
