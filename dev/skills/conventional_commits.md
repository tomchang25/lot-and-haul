# Conventional Commits 1.0.0

> A specification for adding human and machine readable meaning to commit messages

---

## Summary

The Conventional Commits specification is a lightweight convention on top of commit messages. It provides an easy set of rules for creating an explicit commit history, which makes it easier to write automated tools on top of. This convention dovetails with [SemVer](http://semver.org), by describing the features, fixes, and breaking changes made in commit messages.

### Commit Message Structure

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Structural Elements

1. **`fix:`** patches a bug in your codebase (correlates with `PATCH` in SemVer).
2. **`feat:`** introduces a new feature to the codebase (correlates with `MINOR` in SemVer).
3. **`BREAKING CHANGE:`** a commit with a `BREAKING CHANGE:` footer, or a `!` after the type/scope, introduces a breaking API change (correlates with `MAJOR` in SemVer). Can be part of any commit type.
4. **Other types** are allowed, e.g. `build:`, `chore:`, `ci:`, `docs:`, `style:`, `refactor:`, `perf:`, `test:`, and others.
5. **Footers** other than `BREAKING CHANGE: <description>` may be provided following the [git trailer format](https://git-scm.com/docs/git-interpret-trailers).

> A scope may be provided to a commit's type for additional contextual information, contained within parentheses, e.g., `feat(parser): add ability to parse arrays`.

---

## Examples

### Commit message with description and breaking change footer

```
feat: allow provided config object to extend other configs

BREAKING CHANGE: `extends` key in config file is now used for extending other config files
```

### Commit message with `!` to draw attention to breaking change

```
feat!: send an email to the customer when a product is shipped
```

### Commit message with scope and `!`

```
feat(api)!: send an email to the customer when a product is shipped
```

### Commit message with both `!` and `BREAKING CHANGE` footer

```
feat!: drop support for Node 6

BREAKING CHANGE: use JavaScript features not available in Node 6.
```

### Commit message with no body

```
docs: correct spelling of CHANGELOG
```

### Commit message with scope

```
feat(lang): add Polish language
```

### Commit message with multi-paragraph body and multiple footers

```
fix: prevent racing of requests

Introduce a request id and a reference to latest request. Dismiss
incoming responses other than from latest request.

Remove timeouts which were used to mitigate the racing issue but are
obsolete now.

Reviewed-by: Z
Refs: #123
```

---

## Specification

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in [RFC 2119](https://www.ietf.org/rfc/rfc2119.txt).

1. Commits **MUST** be prefixed with a type (a noun: `feat`, `fix`, etc.), followed by the OPTIONAL scope, OPTIONAL `!`, and REQUIRED terminal colon and space.
2. The type `feat` **MUST** be used when a commit adds a new feature to your application or library.
3. The type `fix` **MUST** be used when a commit represents a bug fix for your application.
4. A scope **MAY** be provided after a type. A scope **MUST** consist of a noun describing a section of the codebase surrounded by parentheses, e.g., `fix(parser):`.
5. A description **MUST** immediately follow the colon and space after the type/scope prefix. The description is a short summary of the code changes, e.g., `fix: array parsing issue when multiple spaces were contained in string`.
6. A longer commit body **MAY** be provided after the short description, providing additional contextual information. The body **MUST** begin one blank line after the description.
7. A commit body is free-form and **MAY** consist of any number of newline-separated paragraphs.
8. One or more footers **MAY** be provided one blank line after the body. Each footer **MUST** consist of a word token, followed by either a `:<space>` or `<space>#` separator, followed by a string value (inspired by the [git trailer convention](https://git-scm.com/docs/git-interpret-trailers)).
9. A footer's token **MUST** use `-` in place of whitespace characters, e.g., `Acked-by` (to differentiate the footer section from a multi-paragraph body). An exception is made for `BREAKING CHANGE`, which **MAY** also be used as a token.
10. A footer's value **MAY** contain spaces and newlines, and parsing **MUST** terminate when the next valid footer token/separator pair is observed.
11. Breaking changes **MUST** be indicated in the type/scope prefix of a commit, or as an entry in the footer.
12. If included as a footer, a breaking change **MUST** consist of the uppercase text `BREAKING CHANGE`, followed by a colon, space, and description, e.g., `BREAKING CHANGE: environment variables now take precedence over config files`.
13. If included in the type/scope prefix, breaking changes **MUST** be indicated by a `!` immediately before the `:`. If `!` is used, `BREAKING CHANGE:` **MAY** be omitted from the footer section, and the commit description **SHALL** be used to describe the breaking change.
14. Types other than `feat` and `fix` **MAY** be used in your commit messages, e.g., `docs: update ref docs`.
15. The units of information that make up Conventional Commits **MUST NOT** be treated as case-sensitive by implementors, with the exception of `BREAKING CHANGE` which **MUST** be uppercase.
16. `BREAKING-CHANGE` **MUST** be synonymous with `BREAKING CHANGE` when used as a token in a footer.

---

## Why Use Conventional Commits

- Automatically generating CHANGELOGs.
- Automatically determining a semantic version bump (based on the types of commits landed).
- Communicating the nature of changes to teammates, the public, and other stakeholders.
- Triggering build and publish processes.
- Making it easier for people to contribute to your projects, by allowing them to explore a more structured commit history.

---

## FAQ

### How should I deal with commit messages in the initial development phase?

Proceed as if you've already released the product. Typically somebody — even if it's your fellow software developers — is using your software. They'll want to know what's fixed, what breaks, etc.

### Are the types in the commit title uppercase or lowercase?

Any casing may be used, but it's best to be consistent.

### What do I do if the commit conforms to more than one of the commit types?

Go back and make multiple commits whenever possible. Part of the benefit of Conventional Commits is its ability to drive us to make more organized commits and PRs.

### Doesn't this discourage rapid development and fast iteration?

It discourages moving fast in a disorganized way. It helps you move fast long term across multiple projects with varied contributors.

### Might Conventional Commits lead developers to limit the type of commits they make?

Conventional Commits encourages more of certain types of commits such as fixes. Beyond that, the flexibility of Conventional Commits allows your team to come up with their own types and change those types over time.

### How does this relate to SemVer?

| Commit type       | SemVer release |
|-------------------|----------------|
| `fix`             | `PATCH`        |
| `feat`            | `MINOR`        |
| `BREAKING CHANGE` | `MAJOR`        |

### How should I version my extensions to the Conventional Commits Specification?

Use SemVer to release your own extensions to this specification.

### What do I do if I accidentally use the wrong commit type?

**If the type is in the spec but incorrect** (e.g., `fix` instead of `feat`): Prior to merging or releasing, use `git rebase -i` to edit the commit history. After release, the cleanup will depend on your tools and processes.

**If the type is not in the spec** (e.g., `feet` instead of `feat`): It's not the end of the world. That commit will simply be missed by tools that are based on the spec.

### Do all my contributors need to use the Conventional Commits specification?

No! If you use a squash-based workflow on Git, lead maintainers can clean up the commit messages as they're merged — adding no workload to casual committers.

### How does Conventional Commits handle revert commits?

Conventional Commits does not make an explicit effort to define revert behavior. Instead, it leaves it to tooling authors to use the flexibility of *types* and *footers* to develop their own logic for handling reverts.

One recommendation is to use the `revert` type with a footer referencing the commit SHAs being reverted:

```
revert: let us never again speak of the noodle incident

Refs: 676104e, a215868
```

---

*Licensed under [Creative Commons - CC BY 3.0](https://creativecommons.org/licenses/by/3.0/)*