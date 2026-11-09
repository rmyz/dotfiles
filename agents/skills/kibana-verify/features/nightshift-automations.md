# Nightshift automations (alert trigger, v1 and v2)

Status: draft

## Reach
API only. Base path is random (root redirects). elastic/changeme. Headers: `kbn-xsrf: x`, `x-elastic-internal-origin: kibana`.

## Data
Stateful stack needs one-time setup before `POST /internal/nightshift/automations` works ("Nightshift is not set up in this space"):
1. ES roles `nightshift_agent` and `nightshift_automations` from `common/service_account_roles.ts` (PUT `_security/role/<name>`). Add index read on `.rule-events` and `.alerts-*` to `nightshift_automations`, or v2 alert lookup returns "Alert with id ... not found".
2. `POST /internal/security/service_account` for `nightshift_agent` and `nightshift_automations` (roles of the same name).
3. `POST /internal/nightshift/investigations/service_account/_enable` body `{"serviceAccountIds":{"agent":"kibana/nightshift_agent","automations":"kibana/nightshift_automations"}}`.
4. `POST /internal/nightshift/onboarding/enable`.
Automation body: `{"name","isEnabled":true,"trigger":{"rows":[{"kind":"alert","ruleNamePattern":"x"?}]},"execution":{},"completions":[{"action":"create_investigation"}],"runtime":{}}`.
v2 alert with a rule: index a doc into an index, `POST /api/alerting/v2/rules` (kind alert, ESQL `FROM idx | STATS c=MAX(cpu) BY host.name`, breach `WHERE c > 0.5`, schedule every 1m, grouping host.name). Index a new host doc to get a new alert.
Rule-less v2 alert: workflow with a `manual` trigger and step `alerting.create_alert` (`source`, `fingerprint`, `alert_status: active`), run via `POST /api/workflows/workflow/<id>/run`.

Real significant event (source `elastic.significant_events`, data.event_id/title): `POST /api/agent_builder/tools/_execute` (no elastic-api-version header) body `{"tool_id":"platform.sig_events.event_create","tool_params":{title,symptom_hypothesis,summary,confidence (0..1),slugs:[<nightshift source slug from GET /internal/nightshift/sources>],status:"active",severity}}`. It writes the `.rule-events` alert doc and fires the alert automation within seconds. `alerting.create_alert` cannot be used: source must not start with "elastic".
Oversize data: index an alert doc straight into `.rule-events` (`data` is `flattened`; needs `op_type=create`), then `POST /internal/nightshift/investigations` body `{"subject":{"type":"alert","ids":[<alert.id>]}}`. A direct doc does not fire the automation.
Read investigations: `GET /internal/investigations/investigations?per_page=20` (header `elastic-api-version: 1`; subjects and snapshot included). First round message: ES `.chat-conversations-000001/_doc/<investigation id>` `conversation_rounds[0].input.message`. UI: `/app/agent_builder/agents/nightshift.investigation/conversations/<id>?openConversationDetails=true&sidebarCollapsed=true` (title and subject rows in the right panel).
Re-runnable driver: `~/Code/ai-generated/files/sigevent_drive.sh [prefix] [event|big|both]`.

## Doctor
`GET /api/workflows/workflow/<automation name>` returns yaml with triggers `alerting.v1.alertStatusChanged` and `alerting.alertStatusChanged`.

## Drive
1. Create the automation, read its workflow yaml: both triggers and steps `trigger_investigation_alert` and `trigger_investigation_alert_v2`.
2. Fire a v2 alert. Read executions from ES: `.workflows-executions` (fields workflowId, status, triggeredBy, error) and `.workflows-step-executions` (workflowRunId, stepId, status, output). Expect triggeredBy `alerting.alertStatusChanged`.
3. Filtered automation (ruleNamePattern not matching): no execution at all.

## Gotchas
- Investigation title is replaced by an Agent Builder generated title after the first round (first API read shows "New conversation", pending). The `data.title` fallback of the trigger step is not visible end to end; test it in unit tests.
- Oversize snapshot check: 400 signals (53k chars) became 200 signals, `data.signals_truncated: 400`, 26k chars.
- Many `srctest-*` automations exist on the stack; the driver disables every enabled automation except `sigevent-drive`.
- No `GET /api/workflows/executions` list route; query ES indices above.
- Other enabled alert workflows fire on the same alert and race on the investigation claim ("was modified concurrently"). Disable them while testing.
- Step output `skip_reason: investigation_limit` means the global open-investigation quota is full.
- Rule-less v2 alert (create_alert) used to fail the step with ZodError `rule_id` null; fixed by making v2AlertSnapshotSchema.rule_id optional.
- External `inactive` events from create_alert do not fire the v2 trigger, so follow_up_recovered_alert_v2 needs a real recovering v2 rule to test.
- `GET /internal/significant_events/run_quotas` returns 403 "not available in this environment" until the flag is on. Put `feature_flags.overrides: { nightshift.enabled: true }` in the worktree's `config/kibana.dev.yml` (git-ignored). Dev Kibana restarts by itself.
- Force the global investigation limit: `PUT /internal/significant_events/run_quotas` body `{"limits":{"investigation":1}}`, then `POST /internal/significant_events/run_quotas/_consume` body `{"group":"investigation"}`. `isReached` needs limit > 0 and count >= limit. Restore with `{"limits":{"investigation":3}}`. The count only resets at 00:00 UTC.
- ES calls in zsh: keep curl auth in an array (`ES=(-u elastic:changeme -H '...')`, `"${ES[@]}"`). An unquoted string variable is not word-split and gives a 401 with user " elastic".
- UI: automation detail flyout URL is `/app/nightshift/automations/<id>`, create flyout is `/app/nightshift/automations/new`. agent-browser `click` on Edit sometimes does nothing; click via `eval` on the button found by text. The create flyout shows the daily limit field only after "Add trigger" then "Alert triggered".
