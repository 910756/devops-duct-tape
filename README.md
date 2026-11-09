# devops-duct-tape 🩹

**Emergency DevOps patches that unblock you now and log the tech debt so you fix it properly later.**

Production is on fire, CI is red, or the release is stuck behind a Terraform lock. You don't need a re-architecture right now. You need a safe patch in minutes, plus an honest record of what still needs a permanent fix.

`ducttape` is a small, dependency-free Bash toolkit built on three rules:

1. **Dry run by default.** Nothing changes until you add `--apply`.
2. **Smallest safe fix first.** Stop the bleeding, then move on.
3. **Every patch becomes a debt ticket.** Each applied fix is logged in `DEBT.md`, and optionally as a GitHub issue, with the permanent fix it still needs.

## Fixes

| Command | Fixes | What it does |
|---|---|---|
| `ducttape k8s-crashloop` | Pods stuck in `CrashLoopBackOff` | Shows previous-container logs, events and exit reasons; can roll back the deployment |
| `ducttape tf-unlock` | `Error acquiring the state lock` | Detects the stale lock ID and force-unlocks it safely |
| `ducttape cert-expiry` | Surprise TLS expiry outages | Checks domains and fails if a cert expires within N days (CI and cron friendly) |
| `ducttape disk-cleanup` | `No space left on device` on runners | Prunes old Docker images, containers, build cache, journals and package caches |
| `ducttape retry` | Flaky CI steps | Exponential-backoff retries, logging flaky commands as debt |
| `ducttape debt` | Forgotten hotfixes | Shows the tech-debt log |

## Quick start

```bash
git clone https://github.com/910756/devops-duct-tape.git
cd devops-duct-tape
export PATH="$PWD/bin:$PATH"

ducttape --help
```

### Examples

```bash
# Why is my app crashlooping? (read-only)
ducttape k8s-crashloop -n payments

# Roll it back to the last good release and log the debt
ducttape k8s-crashloop -n payments -d payments-api --rollback --apply

# Pipeline stuck on a Terraform lock
ducttape tf-unlock -C infra/prod            # shows the lock owner and ID
ducttape tf-unlock -C infra/prod --apply    # releases it

# Cert check in CI: fails if anything expires within 30 days
ducttape cert-expiry --days 30 example.com api.example.com

# Runner out of disk
ducttape disk-cleanup            # preview
sudo ducttape disk-cleanup --apply

# Flaky dependency install in CI
ducttape retry --attempts 4 -- npm ci
```

### The debt log

After an applied fix, `DEBT.md` gets a row like this:

| When (UTC) | Severity | Patch applied | Permanent fix needed |
|---|---|---|---|
| 2026-11-09T14:02Z | HIGH | Rolled back deployment/payments-api in payments after CrashLoopBackOff | Find the root cause in the failing release, fix it, add a readiness probe and a pre-deploy smoke test, then redeploy |

Set `DUCTTAPE_GH_ISSUE=1` to also open a GitHub issue labelled `tech-debt` (needs the `gh` CLI).

## Requirements

Bash 3.2+ (works on the macOS default shell). Each fix only needs the tool it touches: `kubectl`, `terraform`, `openssl` or `docker`.

## Need it fixed today?

I'm **Sanjay Singh**, a Senior DevOps and Performance Engineer with 14+ years at banks, telecoms and SaaS companies (ING, Rabobank, KPN). I'm Azure-certified (AZ-104, AZ-700) and based in the Netherlands (CET).

If your pipeline, cluster or cloud is broken and you need it working **today**, I offer an **emergency DevOps fix within 24 hours**: a safe patch first, then a clear plan for the permanent fix.

👉 **[Hire me on Upwork](https://www.upwork.com/freelancers/~01e599e4dff6cdf399)**

## License

MIT, see [LICENSE](LICENSE).
