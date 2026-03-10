# Contributing to Smainer

Thanks for your interest in contributing.

## Development Model

Smainer is organized as a multi-repo system wired through submodules in this repository:
- `backend/` -> https://github.com/Smainer/smainer-backend
- `contracts/` -> https://github.com/Smainer/smainer-contracts
- `frontend/` -> https://github.com/Smainer/smainer-frontend
- `telegram/` -> https://github.com/Smainer/smainer-telegram
- `desktop/` -> https://github.com/Smainer/smainer-desktop

Most feature work should happen in the component repository first.

## How to Contribute

1. Fork the relevant repository.
2. Create a feature branch from `main`.
3. Add tests for behavior changes.
4. Run lint/build/tests locally.
5. Open a pull request with a clear summary and risk notes.

## Commit Style

Use conventional commit style where possible:
- `feat(scope): description`
- `fix(scope): description`
- `docs(scope): description`
- `chore(scope): description`

## Pull Request Checklist

- [ ] Change is scoped and explained.
- [ ] Tests were added/updated when needed.
- [ ] Lint/build checks pass.
- [ ] No secrets or private keys are included.
- [ ] Documentation was updated when behavior changed.

## Security Issues

Do not open public issues for sensitive vulnerabilities.
Use the process in `SECURITY.md`.
