# GENERATED FILE -- do not hand-edit. Source: .devcontainer/devcontainer.answers.json
# generator: dev-container-config  schemaVersion: 1  content-hash: 42722bc87f2aefbcb37382a5049e670366b6ed05a7fba6f981a193046f50cdb2

# Base image standardized across all projects generated from this submodule.
# All tool installs and root-only hardening run here at `docker build` time
# while the build step still runs as root. This cannot be done via sudo in
# postCreateCommand: devcontainer.json's runArgs sets --security-opt
# no-new-privileges, which blocks privilege escalation once the container starts.
FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

# -- Security hardening (must run as root at build time) -----------------------
# Cannot be done via sudo in postCreateCommand -- see note above.
RUN passwd -l root \
    && (deluser vscode sudo 2>/dev/null || true)