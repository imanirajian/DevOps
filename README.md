# DevOps
This repository containing scripts, configurations, and other resources that automate and streamline the DevOps processes for a project. This repo is used to manage infrastructure-as-code, build pipelines, and other automation tools. 

---

## 1. Microservice Tagger
`tag-microservices.sh`

### 🧠 Microservice Git Tagger | Interactive Bash Script
A lightweight yet powerful interactive Bash tool for tagging multiple Git-based microservices consistently and semantically. Built for developer teams managing multiple services with independent versioning.

🛠 **Features:**

🔍 Auto-detects version from:

> `application.properties` (Java microservices)

> `package.json` (Typescript-based frontend)

✅ Semantic version validation

🔁 Interactive confirmation flow per microservice

✍️ Custom tag message per tag

📦 Tag all microservices or just a specific one

🚫 Skip individual or all services via CLI flags

🔐 Full audit log of actions (for traceability)

🧪 Dry-run mode for safe testing

📂 Multi-directory support with clean navigation


📦 **Microservice Structure:**

Backend: 
* `service-information`
* `service-user`
* `service-order`
* `service-payment`
* `service-catalog`
* `service-cart`

Version in: `src/.../application.properties` → `app.version`

Frontend: 
* `service-ui`

Version in: `package.json` → `version`

📋 **Usage:**

Run interactively:

```bash
./tag-microservices.sh
or
bash tag-microservices.sh
```

Optional flags:

`--dry-run`: No actual git tagging/pushing

`--skip-all`: Skip tagging all services

`--skip=user,payment`: Skip specific services

---