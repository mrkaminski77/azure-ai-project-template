# Project Template

This repo is a template for standing up an AI platform project on Azure: infrastructure-as-code
for every resource, plus the pipelines that keep those resources and their code in sync.

## How it fits together

- **`infra/resources/`** — one folder per resource (e.g. `ai-project/`, `database/`, `function-app/`).
  Each folder holds that resource's own definition: a `main.bicep`/`main.bicepparam` pair and a
  `*-config.yml` file with the settings specific to that resource. `infra/env-config.yml` and
  `infra/project-config.yml` hold the shared, cross-resource settings (subscription, resource
  group, naming, etc.) that every resource definition pulls in.
- **`infra/bicep-modules/`** — shared Bicep modules that the resource definitions compose together.
- **`infra/pipelines/`** — one pipeline per resource, triggered on changes under its matching
  `infra/resources/<resource>/**` path. When a resource's definition changes, its pipeline deploys
  the update — you don't redeploy the whole project to change one resource.
- **`code/`** — pipelines (and any supporting scripts) for deploying application code that lives in
  *other* repositories. Each deployable app (e.g. a function app) has its own repository in the
  project; the pipeline here watches that repo via a multi-repo `resources.repositories` trigger
  and deploys its code (for example, zip-deploying a function app) whenever its `main` branch
  changes. Infrastructure and application code are versioned and deployed independently.
- **`register-pipelines.ps1`** — `az pipelines create` commands to register the YAML pipelines in
  `infra/pipelines/` and `code/pipelines/` against your Azure DevOps project.
- **`docs/`** — high-level documentation describing how the components (resources, pipelines, external repos) fit together for this project.
  - [`docs/naming-and-identity-conventions.md`](docs/naming-and-identity-conventions.md) — rules and patterns for resource naming, environment suffixes, and system-assigned managed identity role assignments.

## Adding another instance of a resource

To stand up multiple instances of the same resource type (e.g. more than one function app), copy
its folder under `infra/resources/`, give the copy its own config values, and point its pipeline's
trigger path at the new folder. No changes to the shared modules are needed.
