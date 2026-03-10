<div align="center">

# Contributing to Smainer

*Thank you for your interest in contributing to the decentralized compute-sharing protocol!*

</div>

---

## Development Model

Smainer is organized as a multi-repo system wired through submodules in this repository:

| Submodule | Repository |
|-----------|------------|
| `backend/` | [Smainer/smainer-backend](https://github.com/Smainer/smainer-backend) |
| `contracts/` | [Smainer/smainer-contracts](https://github.com/Smainer/smainer-contracts) |
| `frontend/` | [Smainer/smainer-frontend](https://github.com/Smainer/smainer-frontend) |
| `telegram/` | [Smainer/smainer-telegram](https://github.com/Smainer/smainer-telegram) |
| `desktop/` | [Smainer/smainer-desktop](https://github.com/Smainer/smainer-desktop) |

Most feature work should happen in the component repository first.

---

## How to Contribute

1. **Fork** the relevant repository.
2. **Create** a feature branch from `main`.
3. **Add tests** for behavior changes.
4. **Run** lint/build/tests locally.
5. **Open** a pull request with a clear summary and risk notes.

---

## Commit Style

Use conventional commit style where possible:

```
feat(scope): description
fix(scope): description
docs(scope): description
chore(scope): description
```

---

## Pull Request Checklist

- [ ] Change is scoped and explained.
- [ ] Tests were added/updated when needed.
- [ ] Lint/build checks pass.
- [ ] No secrets or private keys are included.
- [ ] Documentation was updated when behavior changed.

---

## Security Issues

Do not open public issues for sensitive vulnerabilities.
Use the process in [`SECURITY.md`](SECURITY.md).
