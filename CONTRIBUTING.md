# Contributing to DeskFlow

Thanks for your interest in contributing to DeskFlow! 🎉

## How to Contribute

### Reporting Bugs

1. Check if the issue already exists in [GitHub Issues](https://github.com/loydhale/deskflows/issues)
2. Create a new issue with:
   - Clear description of the problem
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details (OS, browser, version)

### Suggesting Features

1. Open a [GitHub Issue](https://github.com/loydhale/deskflows/issues/new) with the `enhancement` label
2. Describe the feature and its use case
3. Explain why it would benefit DeskFlow users

### Pull Requests

1. Fork the repository
2. Create a feature branch from `develop`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Make your changes
4. Write/update tests as needed
5. Ensure all tests pass:
   ```bash
   bundle exec rspec
   pnpm test
   ```
6. Follow code style guidelines:
   ```bash
   bundle exec rubocop
   pnpm lint
   ```
7. Commit with clear messages
8. Push and open a PR against `develop`

## Development Setup

See the [README](README.md) for development environment setup instructions.

## Code Style

- **Ruby**: Follow [Ruby Style Guide](https://rubystyle.guide/), enforced by RuboCop
- **JavaScript/Vue**: Follow ESLint configuration
- **Commits**: Use clear, descriptive commit messages

## Questions?

- Open a [GitHub Discussion](https://github.com/loydhale/deskflows/discussions)
- Email: support@growlocals.ai

## Attribution

DeskFlow is built on [DeskFlows](https://github.com/deskflows/deskflows). For upstream contributions, please consider contributing to the original project as well.

---

Thank you for helping make DeskFlow better! 🚀
