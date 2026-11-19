# Nightshift automations (alert trigger, v1 and v2)

Status: draft

## Reach
API only. Base path is random (root redirects).

## Data
Stateful stack needs one-time setup before `POST /internal/nightshift/automations` works ("Nightshift is not set up in this space"):
1. ES roles `nightshift_agent` and `nightshift_automations`: `PUT _security/role/<name>` with the definitions in `service_account_roles.ts` (find it with `rg --files -g service_account_roles.ts`). Add the index privilege `{"names":[".rule-events",".alerts-*"],"privileges":["read"]}` to `nightshift_automations`, or v2 alert lookup returns "Alert with id ... not found".
2. `POST /internal/security/service_account` for `nightshift_agent` and `nightshift_automations` (roles of the same name).
3. `POST /internal/nightshift/investigations/service_account/_enable` body `{"serviceAccountIds":{"agent":"kibana/nightshift_agent","automations":"kibana/nightshift_automations"}}`.
4. `POST /internal/nightshift/onboarding/enable`.
Automation body: `{"name","isEnabled":true,"trigger":{"rows":[{"kind":"alert","ruleNamePattern":"x"?}]},"execution":{},"completions":[{"action":"create_investigation"}],"runtime":{}}`.
v2 alert with a rule: index a doc into an index, `POST /api/alerting/v2/rules` (kind alert, ESQL `FROM idx | STATS c=MAX(cpu) BY host.name`, breach `WHERE c > 0.5`, schedule every 1m, grouping host.name). Index a new host doc to get a new alert.
Rule-less v2 alert: workflow with a `manual` trigger and step `alerting.create_alert` (`source`, `fingerprint`, `alert_status: active`), run via `POST /api/workflows/workflow/<id>/run`.

Real significant event (source `elastic.significant_events`, data.event_id/title): `POST /api/agent_builder/tools/_execute` (no elastic-api-version header) body `{"tool_id":"platform.sig_events.event_create","tool_params":{title,symptom_hypothesis,summary,confidence (0..1),slugs:[<nightshift source slug from GET /internal/nightshift/sources>],status:"active",severity}}`. It writes the `.rule-events` alert doc and fires the alert automation within seconds. `alerting.create_alert` cannot be used: source must not start with "elastic".
Read investigations: `GET /internal/investigations/investigations?per_page=20` (header `elastic-api-version: 1`; subjects and snapshot included). First round message: ES `.chat-conversations-000001/_doc/<investigation id>` `conversation_rounds[0].input.message`. UI: `/app/agent_builder/agents/nightshift.investigation/conversations/<id>?openConversationDetails=true&sidebarCollapsed=true` (title and subject rows in the right panel).

## Doctor
`GET /api/workflows/workflow/<automation name>` returns yaml with triggers `alerting.v1.alertStatusChanged` and `alerting.alertStatusChanged`.

## Drive
1. Create the automation, read its workflow yaml: both triggers and steps `trigger_investigation_alert` and `trigger_investigation_alert_v2`.
2. Fire a v2 alert. Read executions from ES: `.workflows-executions` (fields workflowId, status, triggeredBy, error) and `.workflows-step-executions` (workflowRunId, stepId, status, output). Expect triggeredBy `alerting.alertStatusChanged`.
3. Filtered automation (ruleNamePattern not matching): no execution at all.

## Gotchas
- Investigation title is replaced by an Agent Builder generated title after the first round (first API read shows "New conversation", pending). The `data.title` fallback of the trigger step is not visible end to end; test it in unit tests.
- Many `srctest-*` automations exist on the stack; the driver disables every enabled automation except `sigevent-drive`.
- No `GET /api/workflows/executions` list route; query ES indices above.
- Other enabled alert workflows fire on the same alert and race on the investigation claim ("was modified concurrently"). Disable them while testing.
- Step output `skip_reason: investigation_limit` means the global open-investigation quota is full.
- External `inactive` events from create_alert do not fire the v2 trigger, so follow_up_recovered_alert_v2 needs a real recovering v2 rule to test.
- `GET /internal/significant_events/run_quotas` returns 403 "not available in this environment" until the flag is on. Put `feature_flags.overrides: { nightshift.enabled: true }` in the worktree's `config/kibana.dev.yml` (git-ignored). Dev Kibana restarts by itself.
- Force the global investigation limit: `PUT /internal/significant_events/run_quotas` body `{"limits":{"investigation":1}}`, then `POST /internal/significant_events/run_quotas/_consume` body `{"group":"investigation"}`. `isReached` needs limit > 0 and count >= limit. Read the current limits with `GET /internal/significant_events/run_quotas` first and restore them afterwards. The count only resets at 00:00 UTC.
- ES calls in zsh: keep curl auth in an array (`ES=(-u elastic:changeme -H '...')`, `"${ES[@]}"`). An unquoted string variable is not word-split and gives a 401 with user " elastic".
- UI: automation detail flyout URL is `/app/nightshift/automations/<id>`, create flyout is `/app/nightshift/automations/new`. The create flyout shows the daily limit field only after "Add trigger" then "Alert triggered".

## Seeding and reading runs
Per-automation run totals: `POST /internal/nightshift/automations/run_counts` body `{"ids":[...],"startedAfter"?,"startedBefore"?}` returns `{"counts":{"<id>":{"succeeded","running","failed","skipped"}}}`.
Seed runs: create an automation (an unmatched `ruleNamePattern` keeps it idle) and read `workflowId` from the create response (a lingering workflow makes it `<name>-1`). `_bulk?refresh=true` into `.workflows-executions` with `{id,spaceId:"default",workflowId,status,startedAt,createdAt,finishedAt,triggeredBy:"manual",scopeStack:[],stepExecutionIds:[]}`. For each skipped run add a doc into `.workflows-step-executions` with `{id,spaceId,workflowId,workflowRunId,stepId:"trigger_investigation_alert_v2",startedAt,output:{skip_reason:"daily_limit"}}`.
Check: `succeeded`, `running` and `failed` equal `_count` on `.workflows-executions` filtered by `workflowId`, status (`terms`) and `range` on startedAt. `output` is unmapped, so ES queries on `output.skip_reason` return 0: count `skipped` in a script over step `_source` filtered by trigger stepIds. `GET .../<id>/runs?size=100` returns 100 runs per page (`?searchAfter=[ts,"id"]` pages on), so use run_counts for exact totals.
Gotchas: `DELETE /internal/nightshift/automations/<id>` returns 500 "Cannot delete workflow with running executions" while seeded `running` docs exist. Delete the seeded docs with `_delete_by_query` on workflowId in both indices first. The UI list defaults to "Last 48 hours", so seed startedAt within 48h. "Today's usage" reads the hidden `nightshift-automation-budget` saved object, and writing it needs a temp role with `allow_restricted_indices:true`. The flyout "Runs" stat is succeeded+running+failed (skipped excluded).

## Trigger editor (UI)
Open `/app/nightshift/automations/new` (detail: `/automations/<id>`), then "Add trigger" and "Alert triggered". The alert trigger carries `alertSources` (trimmed, 1 to 500 items) and `alertSourceMode` (`include`|`exclude`); known keys: `classic`, `internal`, `elastic.significant_events`. Without sources, the workflow has both `alerting.v1.alertStatusChanged` and `alerting.alertStatusChanged`. With sources, it has only the v2 trigger, and `include` adds `AND event.source:"<key>"` to the condition. Read the workflow with `GET /api/workflows/workflow/<workflowId>`. An API create with `alertSources: [" "]` returns 400 `too_small`.
Selectors: `automationAlertSources` (pill), `automationAlertSourceMode` (buttons `include`, `exclude`), `automationAlertSourcesInput` (combo box). Save, reload, and open Edit to confirm the saved values round-trip.
Gotchas:
- `fill` and `type` work in the combo box. Whitespace plus Enter adds nothing. Free text plus Enter adds a pill.
- Flyout content is outside the main snapshot. Use `snapshot -i -s ".euiFlyout"`.
- The page loads slowly after `open`. Wait 5 s.
- The combo box list auto-opens and covers the mode buttons. Toggle it with `[data-test-subj=automationAlertSourcesInput] [data-test-subj=comboBoxToggleListButton]`. The Tags combo has the same test subject, so scope the selector.
- Mode buttons: `[data-test-subj=automationAlertSourceMode] [data-test-subj=exclude]`.
- Delete test automations with `DELETE /internal/nightshift/automations/<id>`.

## Permissions and service accounts
Stateful setup without SAML: `node -r @kbn/setup-node-env x-pack/solutions/observability/plugins/nightshift_investigations/scripts/create_service_account_roles.ts`; dev.yml `xpack.security.serviceAccounts.enabled: true`, `xpack.encryptedSavedObjects.encryptionKey` (32+ chars), `server.publicBaseUrl: http://localhost:5601/<base>`; `POST /internal/security/service_account` body `{"name":"nightshift_agent","roles":["nightshift_agent"]}` (same for `nightshift_automations`) BEFORE `_enable`.
Users: `POST localhost:9200/_security/user/<name>` with roles; Kibana roles via `PUT /api/security/role/<role>` with `feature.nightshift: ["read"|"all"]`. `manage_security` is the ES cluster privilege that gates create/edit/delete. Run needs `workflowsManagement`.
Login for agent-browser: fill `input[name=username]`/`input[name=password]`, press Enter, wait 5s.
Schedule trigger body: `{"kind":"schedule","schedulePreset":"hourly"}` plus `execution.promptTemplate`.
Gotchas: creating service accounts after `_enable` gives "bound to an earlier service account": `_disable`, `_enable`, recreate automations. Scheduled run `executedBy` is the creator; the identity is only in workflow yaml `settings.run_as` and `.chat-conversations.user_id`.
