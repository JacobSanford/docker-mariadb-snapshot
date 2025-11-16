---
title: Contributing
description: Guidelines for contributing to docker-mariadb-snapshot
audience: developers
doc_type: reference
tags: [contributing, development, testing]
lastReviewed: 2025-11-16
version: 1.x
---

# Contributing

Contributions are welcome! Please follow these guidelines when submitting pull requests.

## Quick Checklist

### Code Changes

- [ ] All tests pass locally (`./testing/run-tests.sh`)
- [ ] New tests added for new functionality
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Code commented where necessary
- [ ] No new warnings generated

### Documentation Changes

- [ ] Front matter added to new/updated pages (see PR template)
- [ ] Internal links tested (`mkdocs serve`)
- [ ] Code examples tested/verified
- [ ] New pages added to `mkdocs.yml` nav
- [ ] "See Also" sections updated with cross-references
- [ ] No hardcoded version numbers or test counts
- [ ] Images optimized (<500KB) with alt text

## Testing

Run the test suite before submitting:

```bash
cd testing
./testing/run-tests.sh
```

See [Running Tests](running-tests.md) for details.

## Pull Request Template

The full PR checklist is available in `.github/PULL_REQUEST_TEMPLATE.md`.
