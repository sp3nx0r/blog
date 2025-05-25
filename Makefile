.PHONY: dev build clean lint

# Development server with drafts
dev:
	hugo server -D

# Build the site
build:
	hugo --minify

# Clean build artifacts
clean:
	rm -rf public/
	rm -rf resources/_gen/

# Lint markdown files
lint:
	@echo "Checking markdown files..."
	@find content -name "*.md" -exec markdownlint {} \;

# Install development dependencies
setup:
	@echo "Installing development dependencies..."
	npm install -g markdownlint-cli
	pre-commit install

# Create a new post
new-post:
	@read -p "Enter post title: " title; \
	date=$$(date +%Y-%m-%d); \
	dir="content/posts/$$date-$$(echo "$$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"; \
	mkdir -p "$$dir"; \
	hugo new -k post "$$dir/index.md"

# Create a new page
new-page:
	@read -p "Enter page title: " title; \
	hugo new pages/$$(echo "$$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-').md
