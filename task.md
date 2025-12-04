# Krutrim Nexus Ops - Minimalist Cluster Orchestration

- [ ] **Phase 1: Architecture & Restructuring**
    - [x] Rename project to `krutrim-nexus-ops` <!-- id: 0 -->
    - [x] Refactor `install.sh` for Role-based Install (Manager/Worker) <!-- id: 1 -->
    - [ ] **[NEW]** Verify & Fix Directory Structure <!-- id: 2 -->

- [ ] **Phase 2: Core Infrastructure (Tier 1)**
    - [x] Firewall (`nftables.conf`) <!-- id: 3 -->
    - [x] Kernel Hardening (`99-hardening.conf`) <!-- id: 4 -->
    - [x] DNS (`unbound.conf`) <!-- id: 5 -->
    - [x] Privacy (`torrc`, `i2pd.conf`) <!-- id: 6 -->

- [ ] **Phase 3: Minimalist Service Stack (Luke Smith-style)**
    - [ ] **[MODIFY]** Mail: `emailwiz`-style Postfix/Dovecot (Flat files, no SQL) <!-- id: 7 -->
    - [ ] **[NEW]** Storage: SFTP + Nginx Autoindex (No MinIO bloat) <!-- id: 8 -->
    - [ ] **[NEW]** Web/LB: Caddy (Simple reverse proxy) <!-- id: 9 -->
    - [ ] **[NEW]** DB: PostgreSQL (Standard, minimal tuning) <!-- id: 10 -->

- [ ] **Phase 4: Cluster Manager (The "Nexus")**
    - [ ] **[MODIFY]** `nexus.py`: Simple SSH loop wrapper (No heavy deps) <!-- id: 11 -->
    - [ ] **[MODIFY]** `services.py`: Simple process supervisor <!-- id: 12 -->

- [ ] **Phase 5: Verification & Docs**
    - [ ] Update `verify.sh` <!-- id: 13 -->
    - [ ] Update `README.md` <!-- id: 14 -->
