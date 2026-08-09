# Project Agent Memory

## Docker remote

- Docker commands target a remote Docker Engine, so Compose services must not
  bind-mount configuration files from this repository.
- Store runtime configuration in named volumes and manage configuration
  files with `docker cp` from a service-local `Taskfile.yml`.
- Declare volumes that hold runtime data as `external: true` to prevent Compose
  from deleting them accidentally. Create them explicitly before the first
  deployment.
- Volumes that only hold configuration files tracked in this repository may be
  Compose-managed volumes, because `docker cp` can restore their contents from
  the repository and deleting them with the service does not lose unique data.
- Prefer a Compose-managed named volume for repository-managed configuration.
  Mount it over the image's configuration directory, then use the service-local
  `Taskfile.yml` to run `docker compose create` followed by `docker cp` before
  the first `docker compose up -d`. Creating the container initializes a new
  non-external volume from existing files in the image at the mount point even
  when the container has never started, and `docker cp` then replaces or adds
  the repository-managed configuration in that volume.
- If a named configuration volume is not practical, build the service image in
  Compose and use `COPY` in its Dockerfile to bake the repository-managed
  configuration into the image. Follow the Caddy service as the reference for
  this fallback.

## Docker service source labels

- Every open-source application under `service/` whose source is hosted on
  GitHub should declare these container labels in its Compose service:

  ```yaml
  labels:
    service_repository: https://github.com/<ORG>/<REPOSITORY>
  ```

- `service_repository` identifies the application's upstream GitHub source
  repository; do not use this Homelab repository unless it actually contains
  the application source used to build the container.
- `service_git_ref` is optional. When `service_repository` exists and no ref is
  declared, Grafana Alloy supplies `service_git_ref=HEAD`; declare it in Compose
  only when a service needs to pin a different source revision.
- Grafana Alloy converts these Docker labels into GitHub Source Ref metadata for
  Grafana Profiles, letting function details link to and show the corresponding
  source code.
- Preserve any existing Compose labels when adding these source labels.
