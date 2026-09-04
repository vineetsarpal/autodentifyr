# Issue tracker: Linear

Issues and specs for this repo live in the Linear `AutoDentifyr` team (`ATD`). Linear is the authoritative issue tracker; GitHub is used for source control and pull requests.

## Conventions

- Create, read, update, comment on, label, assign, and close issues through the configured Linear integration/API.
- Use the `AutoDentifyr` team (`ATD`) for repository issues unless the user explicitly specifies another team.
- Preserve the Linear workspace, team, project, priority, status, labels, assignee, and relationships.
- Link related GitHub branches and pull requests to the corresponding Linear issue where applicable.
- Do not create duplicate GitHub Issues for work already tracked in Linear.
- Use the repository's existing Linear team and project conventions when they are discoverable.
- If a required Linear workspace, team, project, or workflow detail is unavailable, ask before creating an issue.

## When a skill says “publish to the issue tracker”

Create or update a Linear issue.

## When a skill says “fetch the relevant ticket”

Read the relevant Linear issue, including its description, comments, labels, status, priority, assignee, project, and linked GitHub resources.

## Wayfinding operations

Used by the `wayfinder` skill. A map and its tickets live in the same Linear project and team.

- **Map:** create one issue labelled `wayfinder:map` using the standard Destination, Notes, Decisions so far, Not yet specified, and Out of scope sections.
- **Child ticket:** create an issue with the map issue as `parentId` and one label from `wayfinder:research`, `wayfinder:prototype`, `wayfinder:grilling`, or `wayfinder:task`.
- **Blocking:** use Linear's native `blockedBy` and `blocks` issue relations. A ticket is unblocked when all issues in `blockedBy` are closed.
- **Frontier query:** list the map's open child issues, then exclude tickets with an assignee or an open blocker. Preserve the map's intended ticket order when selecting the first result.
- **Claim:** assign the ticket to `me` before starting work.
- **Resolve:** add the answer as a resolution comment, move the ticket to `Done`, then append a one-line gist and named link to the map's Decisions so far section.
