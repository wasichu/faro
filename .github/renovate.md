# Dependency maintenance

Dependency updates follow Havannah's hosted [Renovate GitHub App](https://github.com/apps/renovate)
setup. The existing installation already has access to `wasichu/faro`. Merge
`renovate.json` to the default branch for the repository policy to take effect. Do not run a second Renovate installation for this repository.
No self-hosted workflow or `RENOVATE_TOKEN` secret is needed.

The policy schedules weekly updates in America/Chicago, maintains `mix.lock`,
groups Hex minor/patch updates, and groups mise and Docker runtime updates.
It also tracks npm packages, Docker Compose, SHA-pinned GitHub Actions, Heroicons' Git tag,
and the Tailwind/esbuild binary versions in `config/config.exs`.
PRs run the same `just ci` checks as local development, plus production release
and Docker builds. Updates require review; they are not automatically merged.

Keep the OTP suffix of the Elixir mise version compatible with Erlang, and keep
Docker's Elixir/OTP versions aligned with `mise.toml` when reviewing runtime PRs.

## Upstream constraint

AshAuthentication 4.15.1 explicitly requires Assent below 0.3.0 (see its
[dependency declaration](https://github.com/team-alembic/ash_authentication/blob/v4.15.1/mix.exs)).
Consequently Assent remains at 0.2.13, which Hex flags for
[CVE-2026-117656](https://osv.dev/vulnerability/EEF-CVE-2026-117656), affecting
Sign in with Apple callbacks. Faro currently has no authentication strategies or
Apple callbacks configured. Do not override the upstream constraint without
compatibility verification; revisit when AshAuthentication permits a fixed version.
