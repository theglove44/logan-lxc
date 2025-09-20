# Infrastructure Repository

This repository provides a clean, modular structure for infrastructure-as-code, environment-specific configurations, documentation, and GitHub collaboration templates.

## Structure

- `docs/` — Architecture, ADRs, and runbooks
- `configs/` — Base and environment-specific configuration
- `infra/` — IaC entry points (Terraform, Ansible, Kubernetes, etc.)
- `scripts/` — Helper scripts (lint/validate/bootstrap)
- `.github/` — Issue and PR templates

## Quick Start

1. Explore `docs/` for architecture and conventions.
2. Place or scaffold your chosen IaC under `infra/`.
3. Add configuration defaults to `configs/base/` and environment overrides to `configs/env/*`.
4. Use `scripts/` for lint and validation hooks you adopt.

## Contributing

See `CONTRIBUTING.md` for guidance on branching, commit style, and PR workflow.

