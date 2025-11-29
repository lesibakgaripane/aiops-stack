
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

