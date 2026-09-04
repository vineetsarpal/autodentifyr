# Domain Docs

How engineering skills should consume this repo's domain documentation.

## Before exploring, read these

- `CONTEXT.md` at the repository root, if it exists.
- `docs/adr/` for architecture decisions related to the area being changed.

If these files do not exist, proceed without flagging their absence. Create them lazily when domain terms or architectural decisions are actually resolved.

## File structure

This is a single-context repository:

```text
/
├── CONTEXT.md
├── docs/adr/
└── lib/
```

## Vocabulary

When naming a domain concept in an issue, proposal, refactor, or test, use the terminology defined in `CONTEXT.md`. If the required concept is not defined there, treat that as a domain-model gap.

## ADR conflicts

If proposed work conflicts with an existing ADR, identify the ADR and explain why it may need to be revisited instead of silently overriding it.
