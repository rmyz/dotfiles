# Nightshift landing and investigation flyout

Status: draft

## Reach
`/app/nightshift`. Card click opens the Agent Builder details flyout and sets `?investigationId=<id>`.

## Data
Investigations already on the stack: `GET /internal/investigations/investigations?per_page=20` (headers `elastic-api-version: 1`, `x-elastic-internal-origin: kibana`). Severity and status live in `.metadata`. Create more with the "Real significant event" request in the Data section of `nightshift-automations.md`.

## Doctor
The landing shows the severity tiles (Critical/High/Medium/Low).

## Drive
1. Click a card. URL gets `investigationId`, flyout shows Status/Severity/Assignees controls.
2. `aria-label="Change severity"` then menuitem Low. Expect `PUT .../investigations/<id>/severity` 200. Expect, without reload, tier list refetches (`severity=...` and `_severity_counts` GETs) and the card moving group.
3. `aria-label="Change status"` then Closed, confirm modal "Close investigation". Expect `PUT .../status` 200.
4. Close flyout (`aria-label="Close this dialog"`): URL param cleared.
5. Card assignee button (`aria-label="Add or change assignees"`), pick a user: `PUT .../assignees` 200, toast "Assignees updated".
Check refetches with `agent-browser network requests | grep -E "PUT|severity="`.

## Gotchas
- Closing declines proposals: destructive to seed data.
- Confirm the dev bundle is current: curl chunks listed by `agent-browser network requests` and grep the new symbol.
