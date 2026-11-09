# Nightshift automations: alert source filter

Status: verified 2026-11-03 (driven end to end except firing a real alert per source)

## Reach
UI: `/app/nightshift/automations` (create: `/automations/new`, detail: `/automations/<id>`). API: `/internal/nightshift/automations` with `kbn-xsrf: x` and `x-elastic-internal-origin: kibana`. Setup as in `nightshift-automations.md`.

## Data
Trigger row fields: `alertSources: string[]` (items trimmed, min 1, max 500) and `alertSourceMode: 'include'|'exclude'`. Known keys: `classic`, `internal`, `elastic.significant_events`.

## Doctor
`GET /internal/nightshift/automations` returns 200.

## Drive
1. API create `{"kind":"alert","alertSources":["elastic.significant_events"],"alertSourceMode":"include"}`. `GET /api/workflows/workflow/<workflowId>` yaml has only `alerting.alertStatusChanged` with `AND event.source:"elastic.significant_events"` in the condition.
2. Exclude `["classic"]`: v2 trigger only, no `event.source` clause.
3. No sources: both `alerting.v1.alertStatusChanged` and `alerting.alertStatusChanged`.
4. `alertSources: [" "]` returns 400 `too_small`.
5. UI: open create flyout, "Add trigger", "Alert triggered". Pill reads "any source" (`automationAlertSources` area). Click it: `automationAlertSourceMode` (buttons `include`, `exclude`) and `automationAlertSourcesInput` combo (Classic, Universal rules, Significant events).
6. Pick Significant events, Save. API shows `["elastic.significant_events"]`. Detail view pill shows "Significant events".
7. Edit: pick `exclude` and Classic, Save, reload, Edit: pill "All except these: Classic", picker shows `exclude` pressed and Classic.
8. Whitespace only plus Enter in the combo adds nothing. Text such as `my.custom` plus Enter adds a pill.

## Gotchas
- Real CDP clicks and key presses from agent-browser often do not reach EUI popovers and combo boxes here. Use `agent-browser eval` with `el.click()` and `dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',keyCode:13,bubbles:true}))`. `fill` and `type` work.
- Flyout content is outside the main snapshot. Use `snapshot -i -s ".euiFlyout"`.
- The page loads slowly after `open`. Wait 5 s.
- The combo box list auto-opens and covers the mode button group. Toggle it with `[data-test-subj=automationAlertSourcesInput] [data-test-subj=comboBoxToggleListButton]`. The Tags combo has the same test subject, so scope the selector.
- Mode buttons: `[data-test-subj=automationAlertSourceMode] [data-test-subj=exclude]`.
- Delete test automations with `DELETE /internal/nightshift/automations/<id>`.
