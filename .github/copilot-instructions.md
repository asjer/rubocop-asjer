# Copilot Instructions — rubocop-asjer

## Project Overview

A RuboCop plugin gem providing custom cops. Uses the **LintRoller plugin system** (RuboCop 1.72+) — not the legacy `require` mechanism. The plugin entry point is `RuboCop::Asjer::Plugin` in [lib/rubocop/asjer/plugin.rb](../lib/rubocop/asjer/plugin.rb), which points RuboCop to [config/default.yml](../config/default.yml) for cop configuration.

## Architecture

```
lib/rubocop/
├── asjer.rb              # Main entry: requires all cops and plugin
├── asjer/
│   ├── plugin.rb         # LintRoller::Plugin — registers cops with RuboCop
│   └── version.rb        # Single source of truth for VERSION
└── cop/asjer/            # All cops live here, one file per cop
config/default.yml        # Default cop config (enabled state, parameters, Include globs)
```

- Each cop is a class under `RuboCop::Cop::Asjer` in `lib/rubocop/cop/asjer/`.
- Every new cop must be: (1) defined in its own file, (2) required in `lib/rubocop/asjer.rb`, and (3) configured in `config/default.yml` with `Description`, `Enabled`, and `VersionAdded`.

## Adding a New Cop

1. Create `lib/rubocop/cop/asjer/<snake_case_name>.rb` — class under `RuboCop::Cop::Asjer`, inheriting `Base`.
2. Add `require_relative 'cop/asjer/<snake_case_name>'` to [lib/rubocop/asjer.rb](../lib/rubocop/asjer.rb).
3. Add default config in [config/default.yml](../config/default.yml) with `VersionAdded` set to current VERSION.
4. Create spec at `spec/rubocop/cop/asjer/<snake_case_name>_spec.rb`.
5. Include YARD `@example` blocks with `# bad` / `# good` in the cop class documentation.
6. Support autocorrect via `extend AutoCorrector` when feasible — both existing cops do.

## Cop Patterns

- Use `def_node_matcher` / `def_node_search` for AST pattern matching (see `NoDefaultTranslation`).
- For complex ordering/sorting logic, extract modules (see `RailsClassOrderDefaults`, `RailsClassOrderCorrector`).
- Include `RangeHelp` when manipulating source ranges for autocorrect.
- Cops that only apply to specific paths use `Include:` in `config/default.yml` (e.g., `RailsClassOrder` targets `app/models/**/*.rb`).
- Configurable method lists: read from `cop_config` with fallback to constants (see `category_methods` in `RailsClassOrder`).

## Testing

```bash
bundle exec rspec                    # Run all tests
bundle exec rspec spec/rubocop/cop/  # Run cop tests only
```

- Tests use `RuboCop::RSpec::ExpectOffense` — use `expect_offense` / `expect_no_offenses` / `expect_correction`.
- Spec files mirror the cop path: `spec/rubocop/cop/asjer/<cop_name>_spec.rb`.
- Include `:config` metadata and set `let(:config) { RuboCop::Config.new }` for default config.
- Test both offense detection and autocorrection in the same example.
- Test custom configuration via `let(:config)` with a `RuboCop::Config.new(hash)` override (see `RailsClassOrder` spec).

## Workflows & Tooling

- **Lint & test**: `bundle exec rake` runs both `rspec` and `rubocop` (default Rake task).
- **Git hooks**: Lefthook with remote config from `asjer/lefthook-configs`.
- **Releases**: Automated via `release-please`; version lives in [lib/rubocop/asjer/version.rb](../lib/rubocop/asjer/version.rb) and changelog in [CHANGELOG.md](../CHANGELOG.md). Don't manually edit either — they're managed by the release pipeline.
- **Ruby**: Requires >= 3.2.0.

## Conventions

- All Ruby files start with `# frozen_string_literal: true`.
- MSG constants use actionable language (tell the user what to do, not just what's wrong).
- Cop names are prefixed `Asjer/` in config and messages.
- No runtime dependencies beyond `rubocop` and `lint_roller`.
