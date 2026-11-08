# GENERATED FILE -- do not hand-edit. Source: ./.devcontainer/devcontainer.answers.json
# generator: dev-container-config  schemaVersion: 2  content-hash: 149ab78903f1e05365ccaec34f63f918b7ffe597e78b184a18e7ac6b9e1d6bfa

# Base image standardized across all projects generated from this submodule.
# All tool installs and root-only hardening run here at `docker build` time
# while the build step still runs as root. This cannot be done via sudo in
# postCreateCommand: devcontainer.json's runArgs sets --security-opt
# no-new-privileges, which blocks privilege escalation once the container starts.
FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

# -- Node.js (NodeSource apt repo; GPG key saved to a keyring, never piped to a
#    shell -- apt verifies package signatures against it at install time) ------
RUN set -eux; \
    apt-get update; \
    apt-get install -y ca-certificates curl gnupg; \
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key -o /etc/apt/keyrings/nodesource.asc; \
    chmod a+r /etc/apt/keyrings/nodesource.asc; \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.asc] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list; \
    apt-get update; \
    apt-get install -y nodejs

# -- Security hardening (must run as root at build time) -----------------------
# Cannot be done via sudo in postCreateCommand -- see note above.
RUN passwd -l root \
    && (deluser vscode sudo 2>/dev/null || true)