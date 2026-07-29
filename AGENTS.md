# Project Agent Memory

## Docker remote

- Docker commands target a remote Docker Engine, so Compose services must not
  bind-mount configuration files from this repository.
- Store runtime configuration in external named volumes and manage configuration
  files with `docker cp` from a service-local `Taskfile.yml`.
- Declare persistent volumes as `external: true` to prevent Compose from deleting
  them accidentally. Create them explicitly before the first deployment.
