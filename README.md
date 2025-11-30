
# AIOps Stack (Unified Portal + AI Services)

The AIOps Stack is a modular, container-based ecosystem designed to provide:
- A unified web portal for Admin, Super-User, and End-User roles
- AI-powered operations automation (AIOps)
- RAG (Retrieval-Augmented Generation) services
- ML-based anomaly detection
- FastAPI microservices
- Integrated cybersecurity awareness (future module)

This repository contains all major components required to deploy and operate the ecosystem.


---

## 🧱 Architecture Overview

The stack consists of multiple independent microservices:

| Component               | Description |
|------------------------|-------------|
| ui-gateway             | FastAPI gateway for authentication + portal integration |
| ai_orchestrator        | Central AI control service |
| aiops-rag-service      | RAG engine for AI troubleshooting |
| aiops-anomaly-service  | ML anomaly detection |
| fastapi_heartbeat      | System heartbeat |
| Nginx                  | Serves the Unified Portal |


---

## 📁 Folder Structure

aiops-stack/
├── ui/
│   ├── ui-gateway/
│   └── portal/
├── ai/
│   ├── rag-service/
│   ├── anomaly-service/
│   └── orchestrator/
├── compose/
├── scripts/
└── aiops_portal_e2e.sh


---

## 🚀 Deployment Overview

The AIOps Stack can run:
- Directly with uvicorn
- Via Docker Compose

The aiops_portal_e2e.sh script validates:
1. Portal landing page
2. Ecosystem status
3. Authentication


---

## 🔑 Authentication

Default credentials (for testing):

username: admin  
password: password  

The UI Gateway returns JSON with the following fields:

- access_token
- token_type
- username


---

## 📝 Notes

- UI Gateway listens on port 8089
- Nginx serves the portal on port 80

---

## 📌 Roadmap

- Admin dashboards
- AIOps analytics (Grafana-style)
- Unified Chat + LLM integration
- Cybersecurity Awareness Training module
- Multi-role user management

---

## 📜 License

Internal Project — LesiBytes Technology (Pty) Ltd.


---

## 🧭 Operator Quickstart (Dev Lab)

This section explains how to bring up the unified AIOps Portal and verify that core components are healthy in a lab/dev environment.

### 1️⃣ Prerequisites

- AIOps stack services already deployed (Prometheus, RAG, anomaly service, etc.) using the existing Docker Compose files.
- Nginx configured to serve the AIOps Unified Portal landing page on **HTTP port 80**.
- Python 3 and a virtual environment for the UI Gateway:
  - ui/ui-gateway/.venv (preferred), or
  - project root .venv.

### 2️⃣ Start the UI Gateway + Portal Checks

From the project root:

```bash
cd ~/aiops-stack
./aiops_portal_bootstrap.sh
```

This script will:

1. Activate the appropriate Python virtualenv (root .venv or ui/ui-gateway/.venv).
2. Start the UI Gateway (app:app via uvicorn) on port **8089**.
3. Run **AIOps UI Auth Sanity Check**:
   - ./aiops_ui_auth_check.sh
   - Verifies /auth/login and /api/auth/me using lab credentials.
4. Run **AIOps Portal E2E Sanity Check**:
   - ./aiops_portal_e2e.sh
   - Verifies:
     - Nginx landing page (/) shows 'AIOps Unified Portal'
     - /status/ecosystem/status returns service JSON
     - /api/auth/login works via Nginx using admin/password

### 3️⃣ Lab Credentials & Roles

- Admin  
  Username: admin  
  Password: password  

- Personal user  
  Username: lesiba  
  Password: password

### 4️⃣ Portal URLs

- Portal: http://<AIOPS_VM_IP>/
- Login via the AIOps landing page.

Once authenticated:

- Home — overview
- AIOps Operations Center — summary from /aiops/summary
- Cybersecurity Awareness — summary from /awareness/summary
- Ecosystem Health — service JSON + table

Chat widget loads automatically on every page.


