# Securimancy

Source for [securimancy.com](https://www.securimancy.com/) — a personal blog by Spencer Koch covering security engineering, homelab projects, and the occasional TTRPG tangent.

Built with [Hugo](https://gohugo.io/) using the [PaperMod](https://github.com/adityatelange/hugo-PaperMod) theme.

## Local Development

Prerequisites: [Hugo Extended](https://gohugo.io/installation/) (v0.147.8+), Node.js (for linting tools).

```bash
# Install lint/spell-check tooling
make setup

# Run the dev server (includes drafts)
make dev

# Production build
make build
```

## Creating Content

```bash
# New blog post (prompts for title, creates dated directory under content/posts/)
make new-post

# New standalone page
make new-page
```

Posts use [page bundles](https://gohugo.io/content-management/page-bundles/) — each post lives in its own directory with an `index.md` and any co-located assets. The `archetypes/post.md` template scaffolds front matter for new posts.

## Linting & Pre-commit

The repo uses [pre-commit](https://pre-commit.com/) hooks for:

- Trailing whitespace and EOF fixes
- YAML validation
- Large file checks (>2 MB)
- Markdown linting (`markdownlint`)
- Spell checking (`cspell`)
- GPS metadata stripping from images (`exiftool`)
- Hugo build verification

```bash
# One-time hook install
pre-commit install

# Lint markdown manually
make lint
```

## Deployment

Deployment is fully automated via GitHub Actions (`.github/workflows/hugo.yml`).

On every push to `main`:

1. **Lint** — runs `markdownlint` against all content.
2. **Build** — installs Hugo Extended, checks out with LFS and submodules, and builds with `hugo --gc --minify`.
3. **Deploy** — publishes the `public/` directory to **GitHub Pages**.

Pull requests run the lint and build steps without deploying.

## Where It's Deployed

The site is live at **<https://www.securimancy.com/>**, served by GitHub Pages with a custom domain. The repo lives at [sp3nx0r/blog](https://github.com/sp3nx0r/blog).
