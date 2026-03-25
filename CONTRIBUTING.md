# Contributing to Agent Marketplace

Thank you for your interest in contributing! This document provides guidelines and standards for contributing to the project.

## Getting Started

1. **Fork** the repository on GitHub
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/agent-marketplace.git
   cd agent-marketplace
   ```
3. **Set up** the development environment:
   ```bash
   docker-compose -f docker-compose.dev.yml up -d
   ```
4. **Create a branch** for your changes (see [Branch Naming](#branch-naming))

## PR Workflow

### Branch Naming
- `feat/description` - New features
- `fix/description` - Bug fixes
- `test/description` - Tests only
- `docs/description` - Documentation changes
- `refactor/description` - Code refactoring

### Pull Request Process
1. **Target branch**: Always create PRs to `develop`, not `main`
2. **PR Title Format**: Use conventional commits format:
   ```
   type(scope): description
   
   Examples:
   - feat(contracts): add staking mechanism
   - fix(bot): handle empty message content
   - test(api): add coverage for error handlers
   ```
3. **PR Body**: Link related issues using `Closes #123` or `Relates to #456`
4. **Review**: Address review comments promptly
5. **Merge**: Maintainers will merge after approval

## Coding Standards

### Solidity (Smart Contracts)
- Follow **Forge** style conventions
- Add **NatDoc** comments to all public functions:
  ```solidity
  /// @notice Stakes tokens in the contract
  /// @param amount The amount to stake
  /// @return success Whether the stake succeeded
  function stake(uint256 amount) public returns (bool success) {
  ```
- Run `forge fmt` before committing
- Ensure `forge test` passes

### Python (Backend/Bot)
- Use **ruff** for formatting: `ruff format .`
- Enable **strict mypy** mode: `mypy --strict`
- Add **type hints** to all functions:
  ```python
  def process_message(content: str, user_id: int) -> dict[str, Any]:
  ```
- Follow PEP 8 naming conventions

### Commit Style
Use **conventional commits**:
```
feat: add new feature
fix: resolve bug
docs: update documentation
test: add tests
refactor: code restructuring
chore: maintenance tasks
```

## Test Requirements

### Smart Contracts
- All new contracts must have tests
- Run: `forge test`
- Coverage requirement: **≥ 90%** for new contracts
- Include both positive and negative test cases

### Python Modules
- Run: `pytest`
- Coverage requirement: **≥ 80%** for new modules
- Mock external dependencies
- Test edge cases and error conditions

## Issue Labeling

| Label | When to Use |
|-------|-------------|
| `bug` | Something isn't working |
| `enhancement` | New feature or request |
| `documentation` | Improvements to docs |
| `good first issue` | Good for newcomers |
| `help wanted` | Extra attention needed |
| `contracts` | Smart contract related |
| `frontend` | UI/UX related |
| `backend` | API/server related |
| `priority/high` | Critical issues |
| `priority/low` | Nice to have |

## Security Issues

**Do not** create public issues for security vulnerabilities.

Instead, email us directly at: **security@agentmarketplace.xyz**

Include:
- Description of the vulnerability
- Steps to reproduce (if applicable)
- Potential impact
- Suggested fix (optional)

We will respond within 48 hours and work with you to resolve the issue before public disclosure.

## Questions?

- Join our [Telegram](https://t.me/agentmarketplace)
- Open a [Discussion](https://github.com/Juwebien/agent-marketplace/discussions)

## Code of Conduct

- Be respectful and inclusive
- Accept constructive criticism gracefully
- Focus on what's best for the community
- Show empathy towards others

Thank you for contributing! 🚀
