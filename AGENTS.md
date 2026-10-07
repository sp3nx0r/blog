# AGENTS.md

Guidance for AI agents working in this repository. Humans should start with [`README.md`](README.md); this file adds the structural/navigational detail agents need to make changes safely.

## What this is

**Securimancy** — the personal blog at [securimancy.com](https://www.securimancy.com/), authored by Spencer Koch (security engineering, homelab, TTRPG topics).

- **Generator:** [Hugo](https://gohugo.io/) (Extended, `v0.147.8+`; CI pins `0.161.1`).
- **Theme:** [PaperMod](https://github.com/adityatelange/hugo-PaperMod), vendored as a git **submodule** at `themes/PaperMod`.
- **Hosting:** GitHub Pages with a custom domain, deployed from `main` via GitHub Actions.
- **Source repo:** [sp3nx0r/blog](https://github.com/sp3nx0r/blog).

## Repository layout

| Path | Purpose |
| --- | --- |
| `hugo.yaml` | Primary site config (baseURL, params, menu, taxonomies, markup, outputs). The single source of truth for site behavior. |
| `content/` | All site content (Markdown). |
| `content/posts/` | Blog posts as **page bundles** (one dir per post). |
| `content/pages/` | Standalone pages (e.g. `about.md`). |
| `content/{archives,search,sitemap}.md` | Special list/utility pages driven by PaperMod layouts. |
| `archetypes/` | Front-matter templates for `hugo new` (`post.md`, `default.md`). |
| `layouts/` | **Local overrides** that sit on top of the theme (see below). |
| `assets/css/extended/custom.css` | Site-specific CSS (PaperMod's sanctioned extension point). |
| `static/` | Files copied verbatim to site root (e.g. `static/images/`). |
| `data/subtitle.md` | Data file read by a shortcode for the profile subtitle. |
| `i18n/` | Local translation overrides (theme ships its own in `themes/PaperMod/i18n/`). |
| `themes/PaperMod/` | **Vendored submodule — do not edit.** Override via `layouts/` and `assets/` instead. |
| `public/`, `resources/` | Build output / Hugo cache. Git-ignored; never edit by hand. |
| `.github/workflows/hugo.yml` | CI: lint → build → deploy. |
| `Makefile` | Common dev commands. |
| `TODO.md` | Author's scratch list (git-ignored). |

## Common commands

Use the `Makefile` targets rather than raw Hugo when possible:

```bash
make dev        # hugo server -D (live reload, includes drafts)
make build      # hugo --minify (production build into public/)
make clean      # remove public/ and resources/_gen/
make lint       # markdownlint across content/*.md
make setup      # install markdownlint-cli globally (npm)
make new-post   # prompts for title → creates dated page bundle + index.md
make new-page   # prompts for title → creates content/pages/<slug>.md
```

## Authoring a blog post

Posts are [page bundles](https://gohugo.io/content-management/page-bundles/): each lives in its own directory `content/posts/YYYY-MM-DD-<slug>/` containing `index.md` plus any co-located assets (typically an `images/` subdir).

- Prefer `make new-post` — it builds the dated directory and scaffolds front matter from `archetypes/post.md`.
- Reference co-located images with `relative: true` in the `cover` block and relative paths in body Markdown.
- Set `draft: false` and a real `date` to publish. Drafts only appear with `hugo server -D`.
- `url:` in front matter sets the permalink (archetype defaults to `/change-me` — always change it).

Key front-matter fields (from `archetypes/post.md`): `title`, `summary`, `draft`, `date`, `creationDate`, `url`, `tags`, optional `showToc`, `cover`/`images`.

## Local overrides vs. the theme

`themes/PaperMod/` is a submodule and must not be modified. Customizations live in the repo root and take precedence over the theme:

- **Templates:** `layouts/` (partials, shortcodes, `robots.txt`, `404.html`, `sitemap/single.html`).
- **Styles:** `assets/css/extended/custom.css`.

### Custom shortcodes (in `layouts/shortcodes/`)

| Shortcode | Usage |
| --- | --- |
| `callout` | Admonition box. Params: `type` (`note`/`tip`/`warning`/`danger`), `title`. Inner is markdownified. |
| `details` | Collapsible `<details>` block. Param: `title` (default "Click to expand"). |
| `years-since` | Computes elapsed years from a date arg, e.g. `{{< years-since "2019-10-01" >}}` (adds "and a half"). |
| `profile-subtitle` | Renders `data/subtitle.md`. Used for the homepage profile subtitle. |
| `table` | Wraps a Markdown table with Bootstrap-ish striped/bordered classes. |
| `readfile` | Inlines a file verbatim. Param: `path` (required). |

## CI / deployment

`.github/workflows/hugo.yml` runs on push and PR to `main`:

1. **lint** — `make setup && make lint` (markdownlint).
2. **build** — installs pinned Hugo Extended, checks out with `submodules: recursive` and `lfs: true`, then `hugo --gc --minify --baseURL "https://www.securimancy.com/"`. The baseURL is hardcoded in CI to avoid mixed-content issues.
3. **deploy** — publishes `public/` to GitHub Pages (only on push to `main`).

PRs run lint + build but do not deploy. **Note:** image assets use Git LFS — clones/checkouts need LFS enabled.

## Conventions & gotchas

- **Pre-commit hooks** (`.pre-commit-config.yaml`): trailing-whitespace, EOF fixer, YAML check, large-file guard (>2 MB), markdownlint, a full `hugo build`, and `exiftool` **GPS-metadata stripping on images**. Run `pre-commit install` once. Do not commit images with GPS EXIF data.
- **Markdown linting** (`.markdownlint.yaml`): line-length (MD013) and inline-HTML (MD033) are disabled; sibling-only duplicate-heading rule; ordered-list style enforced. Keep content lint-clean (`make lint`).
- **Submodule:** after cloning run `git submodule update --init --recursive`, or the theme (and thus the build) will be missing.
- **Don't edit** `public/`, `resources/`, or anything under `themes/PaperMod/`.
- `enableGitInfo: true` means `lastmod` can derive from git history — commit dates matter for display.
- Site config uses `markup.goldmark.renderer.unsafe: true`, so raw HTML in Markdown is allowed and rendered.

## Verifying changes

Before considering a change done:

1. `make build` (or `make dev` and spot-check in the browser) — must succeed; the pre-commit `hugo build` hook will also enforce this.
2. `make lint` — content must pass markdownlint.
3. For new posts, confirm the permalink (`url:`), `draft: false`, cover image path, and tags render correctly.
