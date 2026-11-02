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

## Doctor
`GET /api/workflows/workflow/<automation name>` returns yaml with triggers `alerting.v1.alertStatusChanged` and `alerting.alertStatusChanged`.

## Drive
1. Create the automation, read its workflow yaml: both triggers and steps `trigger_investigation_alert` and `trigger_investigation_alert_v2`.
2. Fire a v2 alert. Read executions from ES: `.workflows-executions` (fields workflowId, status, triggeredBy, error) and `.workflows-step-executions` (workflowRunId, stepId, status, output). Expect triggeredBy `alerting.alertStatusChanged`.
3. Filtered automation (ruleNamePattern not matching): no execution at all.

## Gotchas
- No `GET /api/workflows/executions` list route; query ES indices above.
- Other enabled alert workflows fire on the same alert and race on the investigation claim ("was modified concurrently"). Disable them while testing.
- Step output `skip_reason: investigation_limit` means the global open-investigation quota is full.
- Rule-less v2 alert (create_alert) used to fail the step with ZodError `rule_id` null; fixed by making v2AlertSnapshotSchema.rule_id optional.
- External `inactive` events from create_alert do not fire the v2 trigger, so follow_up_recovered_alert_v2 needs a real recovering v2 rule to test.
