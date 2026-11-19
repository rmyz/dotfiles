# Agentic investigations conversation details

Status: draft

## Reach
`/app/agent_builder/conversations/<conversationId>`, then the "Summary" button (top right) opens the details panel with an "Impact" section. Use a wide viewport (`agent-browser set viewport 1600 1000`); at 1280 wide the click on Summary does nothing visible. Role: elastic. Plugin `agenticInvestigations` is on by default.

## Data
Pick any existing conversation id (`GET /api/agent_builder/conversations`), then attach impact with evidence:

```bash
curl -s -u elastic:changeme -H 'kbn-xsrf: x' -H 'x-elastic-internal-origin: kibana' -H 'elastic-api-version: 1' -H 'content-type: application/json' -X POST "<kibana-url>/internal/investigations/impact" -d '{"conversationId":"<id>","entities":[{"id":"checkout-service","name":"checkout-service","type":"service","evidence":{"description":"Long markdown text"}}]}'
```

## Doctor
`document.querySelectorAll('[data-test-subj=investigationImpactEntityRow]').length` is at least 1 after opening Summary.

## Drive
1. Open the conversation, click the Summary button.
2. Click the chevron button inside `investigationImpactEntityRow`.
3. `investigationImpactEntityEvidence` appears. For a layout check, read the element with getComputedStyle and getBoundingClientRect.

## Gotchas
- Rows without `evidence` have no chevron.
