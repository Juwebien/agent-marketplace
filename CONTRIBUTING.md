# Contributing to Agent Marketplace

Thanks for your interest in contributing! This guide covers everything you need to get started.

## Getting Started

1. **Fork** the repository on GitHub
2. **Clone** your fork locally:

   ```bash
   git clone https://github.com/<your-username>/agent-marketplace.git
   cd agent-marketplace
   ```

3. **Start local infrastructure** (PostgreSQL, Redis):

   ```bash
   docker compose up -d
   ```

4. **Build and test contracts**:

   ```bash
   cd contracts
   forge install
   forge build
   forge test -v
   ```

5. **Set up the bot**:

   ```bash
   cd bot
   cp .env.example .env   # fill in your values
   pip install -r requirements.txt
   ```

## PR Workflow

### Branch naming

Use descriptive branch names with a type prefix:

- `feat/short-description` — new features
- `fix/short-description` — bug fixes
- `test/short-description` — test additions or fixes
- `docs/short-description` — documentation changes

### Submitting a PR

1. Create your branch from `master`
2. Make your changes and commit (see [Commit Style](#commit-style) below)
3. Push to your fork and open a PR against `master`
4. Use [conventional commit](https://www.conventionalcommits.org/) format for the PR title:

   ```
   type(scope): description
   ```

   Examples: `feat(contracts): add dispute resolution`, `fix(bot): handle rate limit`

5. Link the related issue in your PR body (e.g., `Closes #42`)

## Coding Standards

### Solidity

- Follow [Forge style](https://book.getfoundry.sh/reference/config/formatter) conventions
- Add NatSpec documentation (`@notice`, `@param`, `@return`, `@dev`) on all public and external functions
- Use custom errors instead of `require` strings
- Use named imports

### Python

- Format with [ruff](https://docs.astral.sh/ruff/)
- Use type hints on all function signatures
- Run `mypy --strict` with no errors on new code

### Commit Style

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): short description

Optional longer body explaining the change.
```

Types: `feat`, `fix`, `test`, `docs`, `chore`, `refactor`, `ci`

Scopes: `contracts`, `bot`, `infra`, `spec`

## Test Requirements

### Contracts

- `forge test` must pass with no failures
- New contracts must have **≥ 90% line coverage**
- Run coverage: `forge coverage`

### Python

- `pytest` must pass with no failures
- New modules must have **≥ 80% line coverage**
- Run tests: `cd bot && pytest tests/`

## Issue Labels

| Label | When to use |
|-------|------------|
| `bug` | Something isn't working as expected |
| `enhancement` | New feature or improvement |
| `good first issue` | Suitable for newcomers |
| `contracts` | Smart contract–related |
| `bot` | GitHub bot / Python coordinator |
| `infra` | CI, Docker, tooling, repo config |
| `docs` | Documentation updates |
| `testing` | Test additions or fixes |
| `agent-ready` | Spec complete — ready for AI agent pickup |
| `phase-1` | Phase 1 implementation scope |

## Security Issues

**Do not open a public issue for security vulnerabilities.**

Please report security issues responsibly by emailing the maintainers directly. Include:

- Description of the vulnerability
- Steps to reproduce
- Potential impact

The maintainers will acknowledge your report and work on a fix before any public disclosure.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
