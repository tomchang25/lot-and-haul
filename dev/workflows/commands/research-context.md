# research-context — retrieve relevant codebase context

Retrieve relevant codebase context for an idea, scratchboard entry, draft, or small plan so the user can do further research.

This command is read-only. Do not edit files, stage changes, commit, run formatters, or implement the idea.

## Input

The user may provide free-form notes, for example:

```text
[Talk about an idea or a scratchboard entry, draft, small plan]

Please retrieve all relative codebase for me for further research
```

Treat the note as a research brief, not as an implementation request.

## Required Reading

Before searching, read:

- `dev/agent_rules/agent_startup.md`
- Any standards, workflows, docs, or plans that the brief directly names

## Steps

1. Restate the research target in one compact sentence.
2. Identify likely domains, systems, scenes, data, tests, docs, and standards from the brief.
3. Search the repo for relevant terms, symbols, scene names, data names, and related concepts. Prefer `Glob` and `Grep` over shell text tools.
4. Read the most relevant files directly. Do not bulk-read unrelated files or dump broad directories.
5. Follow discovered references when they materially change the research map, but stop before turning retrieval into implementation design.
6. Report only codebase context and reading guidance. Do not propose code changes unless the user asks for implementation planning.

## Output

Return a concise research map with these sections:

1. **Research Target** — the inferred topic and scope.
2. **Most Relevant Files** — file paths with one-line reasons.
3. **Key Entry Points** — classes, scenes, resources, managers, functions, or data files worth starting from.
4. **Related Rules And Docs** — standards, workflows, plans, or docs that constrain the topic.
5. **Suggested Reading Order** — a short ordered path through the files.
6. **Gaps Or Ambiguity** — only if the brief is unclear or important context could not be found.

## Guardrails

- Keep retrieval scoped to relevant codebase context. Do not retrieve the whole repo.
- Do not write a plan, sketch, spec, or implementation unless explicitly asked after the retrieval.
- Do not run tests unless the user specifically asks; this command is for research context, not verification.

$ARGUMENTS
