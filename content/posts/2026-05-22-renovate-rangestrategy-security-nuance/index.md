---
title: "Renovate: rangeStrategy + vulnerabilityAlerts for Security Fixes"
summary: "Why rangeStrategy: widen leaves vulnerable floors in manifests—and how vulnerabilityAlerts with bump fixes security PRs without breaking routine updates"
draft: false
date: 2026-05-22T10:30:00-05:00
creationDate: 2026-05-22T10:30:00-05:00
url: "/renovate-rangestrategy-vulnerabilityalerts"
tags: ["renovate", "security", "dependency-management", "python", "npm"]
showToc: true
images:
  - "images/image.jpeg"
cover:
  image: "images/image.jpeg"
  relative: true
  alt: "Retro sci-fi illustration — S.S. Renovator escaping dependency hell's black hole (rangeStrategy widen vs. bump)"
---

I got a fun ping from one of our developers this week regarding a Renovate PR that was opened in their repo, which is managed by `uv` and includes a `pyproject.toml` config. Typical setup for Python repos at Reddit.

Basically, our internal code review tool had flagged in the Renovate bot PR (bot on bot action) that we weren't also increasing the bounded range in `pyproject.toml` to prevent someone from relocking and being able to take a lower version than currently enforced. Fair comments, actually...

So in this case, it was a typical `cryptography` dependency bump to 46.0.7.  Renovate bumped the `uv.lock` file fine. `pyproject.toml` still says `cryptography>=46.0.6` — the exact version with the reported buffer overflow vulnerability. The lockfile pins you to the fixed version for now, but the manifest still considers the vulnerable version perfectly acceptable.

Is that a problem? It depends on who's asking. For a deployed application with a lockfile, maybe not today. For a library consumed by others, for a fresh environment rebuild, for an auditor checking your declared dependencies — yes, it's a problem. And it's one that Renovate's default configuration doesn't solve for you.

## Manifests vs. Lockfiles: A Quick Refresher

Modern dependency management splits the job between two files:

- **The manifest** (`pyproject.toml`, `package.json`) declares what your project *wants* — version ranges, constraints, the acceptable universe of versions.
- **The lockfile** (`uv.lock`, `package-lock.json`) records what your project *got* — the exact resolved versions from a specific point in time.

The manifest is a contract, whereas the lockfile is a receipt.

## `rangeStrategy`: Widen or Bump

When Renovate updates a dependency, it can touch one or both of these files. The [`rangeStrategy`](https://docs.renovatebot.com/configuration-options/#rangestrategy) configuration controls which approach Renovate takes. And this is where things get interesting, because the right strategy for routine updates is the *wrong* strategy for security fixes. We previously had `rangeStrategy: widen` in our default configs:

```json5
// python.json5 — shared Renovate preset
{
  "packageRules": [
    {
      "description": "Only allow widening Python version constraints in top-level dependency definitions",
      "rangeStrategy": "widen",
      "matchManagers": [
        // PEP621: modern pyproject.toml-style dependencies
        "pep621",
        // Legacy setuptools-based setup.py dependencies
        "pip_setup",
      ],
    },
  ],
}
```

This means Renovate will only modify `pyproject.toml` if a new version falls *outside* the existing range. If the constraint is `>=46.0.6` and a new `46.0.7` is released, Renovate leaves `pyproject.toml` alone and updates only the lockfile. The range already allows the new version, so no change needed!

The reasoning is deliberate. For libraries, tight version constraints are dangerous — every library demanding a specific narrow range makes it exponentially harder for applications to find a dependency tree that satisfies everyone. For applications, unnecessarily tight constraints fight the package manager. If `pyproject.toml` says `cryptography>=46.0.6,<46.0.7` just because that was the latest version when Renovate last ran, commands like `uv add` and `uv upgrade` become less effective. The solver doesn't know if that upper bound exists because of a real incompatibility or because a bot was being overzealous.

The philosophy: pin with *intention* at the manifest level. Let the lockfile handle the day-to-day version pinning. This is good advice — right up until a CVE shows up.

## Why `widen` Is Wrong for Security Fixes

When CVE-2026-39892 was published for `cryptography` 46.0.6, the meaning of our version constraint changes. `>=46.0.6` no longer means "I'm fine with anything from 46.0.6 onward." It means "I'm fine with a version that has a known buffer overflow vulnerability." The constraint doesn't quite reflect reality or our intent.

A lockfile-only update fixes the immediate problem — our resolved dependency tree now uses the safe version. But consider what happens next:

**Fresh installs don't read our lockfile the way we think.** If someone clones our repo and runs `uv sync`, they'll get the lockfile's version. But if they're building a Docker image and the lockfile isn't in the build context, or if they're doing a `uv pip install` without `--frozen`, the solver goes back to the manifest. And the manifest says `>=46.0.6` is fine.

**Libraries propagate the problem downstream.** If our project is a library consumed by other applications, those consumers never see our lockfile. They see our declared constraints. If our `pyproject.toml` says `>=46.0.6`, their solver can legitimately resolve to 46.0.6.

**Auditing becomes misleading.** Tools that scan `pyproject.toml` for known vulnerable ranges will see `>=46.0.6` and may not flag it — after all, the range *includes* the fixed version. But it also includes the vulnerable one. The signal is ambiguous where it should be clear.

**Lockfile regeneration reintroduces risk.** Running `uv lock --upgrade` or even just resolving after adding a new dependency can shift the resolved version. If the solver has a reason to pick 46.0.6 (maybe a constraint from another dependency limits the upper bound), it will. Our manifest said it was OK.

## The One-Line Fix

Renovate's [`vulnerabilityAlerts`](https://docs.renovatebot.com/configuration-options/#vulnerabilityalerts) configuration object lets us override settings specifically for security-related PRs. This includes `rangeStrategy`:

```json
{
  "vulnerabilityAlerts": {
    "rangeStrategy": "bump"
  }
}
```

With `rangeStrategy: "bump"` in `vulnerabilityAlerts`, here's what changes:

| Scenario | Before (widen) | After (bump) |
|---|---|---|
| `pyproject.toml` | `cryptography>=46.0.6` (unchanged) | `cryptography>=46.0.7` |
| `uv.lock` | Updated to 46.0.7 | Updated to 46.0.7 |
| Manifest permits vuln version? | Yes | No |

The `vulnerabilityAlerts` config takes precedence over `packageRules`, so it overrides the `widen` strategy from our Python `packageRules` config without affecting normal dependency updates.

The behavior is now:

- **Normal updates**: `widen` — don't tighten constraints, let the lockfile handle it, avoid dependency hell
- **Security fixes**: `bump` — raise the lower bound, explicitly exclude the vulnerable version, make the manifest truthful

## How This Plays Out Across Ecosystems

`rangeStrategy: "bump"` in `vulnerabilityAlerts` is a global setting, but its effect varies by ecosystem:

**Python (`pyproject.toml`)**: `>=46.0.6` becomes `>=46.0.7`. This is the primary use case. The lower bound moves up to exclude the vulnerable version.

**npm (`package.json`)**: `"^12.0.0"` becomes `"^12.10.2"` (illustrative examples). The caret range still allows anything `>=12.10.2 <13.0.0`, but the floor is raised past the vulnerable version. Same principle, slightly different mechanics.

**Go (`go.mod`)**: No effect. Go modules use exact versions (`require github.com/foo/bar v1.2.3`), not ranges. The lockfile (`go.sum`) and manifest are effectively the same.

**Docker**: No effect. Docker image references are tags or digests, not version ranges.

This means the setting is safe to apply globally — it only changes behavior where version ranges exist, which is exactly where the problem occurs.

## The Gotchas

This isn't a setting you can apply blindly without understanding the edges. The Renovate community has documented some real pitfalls.

### Monorepo lockedVersion contamination

In Python monorepos with multiple `pyproject.toml` files and a shared `uv.lock`, mixing `rangeStrategy: "bump"` with `"update-lockfile"` can cause Renovate to propose *downgrades*. This happens because Renovate uses the root lockfile's resolved version as the baseline for sub-packages, even when those sub-packages have entirely different version constraints.

For example: if your root `uv.lock` resolves `sqlalchemy==1.3.24` but a sub-package declares `sqlalchemy>=2.0.36`, Renovate might propose bumping the sub-package to `>=1.4.54` — a downgrade from the 2.x line. This is a [known bug](https://github.com/renovatebot/renovate/discussions/41719) as of Renovate 43.x. The workaround is to avoid mixing `update-lockfile` overrides with `bump` in the same repository.

### `widen` truly does nothing for lower bounds

This one is subtle. With `rangeStrategy: "widen"`, Renovate will expand the *upper* end of a range but [never raises the lower bound](https://github.com/renovatebot/renovate/discussions/41341). For a constraint like `>=46.0.6`, `widen` means "do nothing" — the range already includes every future version. There's no upper bound to widen.

This is actually the motivation for the whole `vulnerabilityAlerts` override. If you're using `widen` for Python (which you probably should be), Renovate will *never* update `pyproject.toml` for a patch-level security fix, because the existing range already covers the new version. The lockfile update is all you get — unless you override the strategy for security fixes.

### `bump` vs. `replace` vs. `pin`

Renovate has several range strategies, and the naming can be confusing:

- **`bump`**: Raises the lower bound. `>=46.0.6` → `>=46.0.7`. The range is still open-ended. This is what you want for security fixes.
- **`replace`**: Replaces the entire range with Renovate's default for that ecosystem. Can tighten ranges unexpectedly.
- **`pin`**: Converts to an exact version. `>=46.0.6` → `==46.0.7`. Almost never what you want in `pyproject.toml`.
- **`widen`**: Expands the range to include the new version. For `>=X` ranges, this is a no-op.

For the `vulnerabilityAlerts` override, `bump` is the sweet spot — it makes the minimum acceptable version the first safe version, without constraining the upper bound.

## The Broader Picture

The manifest-vs-lockfile distinction is becoming more important as the Python ecosystem matures. `uv` has made lockfiles standard in Python for the first time. pip 26.1 [just shipped](https://www.infoq.com/news/2026/05/pip-261-dependency-cooldowns/) with experimental `pylock.toml` support (PEP 751) and dependency cooldowns. The tooling is getting better at distinguishing "what you declared" from "what you resolved."

But the tooling around *automated updates* hasn't fully caught up. Renovate's default behavior treats the lockfile as the authoritative source of truth, which is correct for deployment but insufficient for security. A vulnerability fix should update both the receipt *and* the contract.

If you're running Renovate at scale and haven't thought about this interaction, it's worth reviewing your config. The fix is one line, but the reasoning behind it touches on some fundamental questions about what your dependency files are actually supposed to mean.

## TL;DR

| | Normal updates | Security fixes |
|---|---|---|
| **Goal** | Keep dependencies current without creating conflicts | Exclude vulnerable versions explicitly |
| **rangeStrategy** | `widen` | `bump` |
| **Manifest updated?** | Only if new version is outside range | Always — lower bound raised to safe version |
| **Lockfile updated?** | Yes | Yes |

```json
{
  "vulnerabilityAlerts": {
    "rangeStrategy": "bump"
  }
}
```

One line. Two different strategies for two different problems.

---

*This is a follow-up to [Dependency Hell, aka How I Learned to Stop Worrying and Love Vulnerability Management](/dependency-hell), which covers the broader dependency management process at Reddit. This post digs into one specific configuration nuance that fell out of operating Renovate across hundreds of repositories.*
