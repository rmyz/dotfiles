# Dynamic synthtrace scenario skeleton

This is a reference for scenarios created by the `kibana-synthetic-data-generation` skill.

## Location (Kibana repo)

Dynamic scenarios live here:

- `${KIBANA_ROOT}/src/platform/packages/shared/kbn-synthtrace/src/scenarios/dynamic/`

This directory must be locally ignored via:

- `${KIBANA_ROOT}/.git/info/exclude`
  - `src/platform/packages/shared/kbn-synthtrace/src/scenarios/dynamic/`

## Authoring rules

- **Filename**: semantic, no SDH/issue numbers (those go in comments).
- **Header comment**: be detailed (goal, usage, options, validation, related refs).
- **Isolation marker**: use `getSynthtraceEnvironment(__filename)` and set `service.environment` (or equivalent) so ES validation can filter cleanly.
- **Stable markers**: prefer predictable prefixes for `service.name`, transaction names, and log messages so validation is easy.
- **Update `dynamic/README.md`**: describe how to use the scenario (no systematic refs).

## TypeScript skeleton (APM example)

```ts
/*
 * Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
 * or more contributor license agreements. Licensed under the "Elastic License
 * 2.0", the "GNU Affero General Public License v3.0 only", and the "Server Side
 * Public License v 1"; you may not use this file except in compliance with, at
 * your election, the "Elastic License 2.0", the "GNU Affero General Public
 * License v3.0 only", or the "Server Side Public License, v 1".
 */

/**
 * <What this scenario is for (UI behavior / bug repro)>.
 *
 * Related:
 * - <links to SDH/issues/PRs> (allowed here; do not put these in dynamic/README.md)
 *
 * Run:
 *   node scripts/synthtrace dynamic/<scenarioBaseName> --from now-1w --to now \
 *     --scenarioOpts='{"rpm":1,"numServices":60}'
 *
 * Manual live run (optional):
 *   node scripts/synthtrace dynamic/<scenarioBaseName> --live --from now-1w --to now \
 *     --scenarioOpts='{"rpm":1,"numServices":60}'
 *
 * Scenario options:
 * - rpm (number, default: 1): traces per minute
 * - numServices (number, default: 60): unique services in a single trace
 * - <...>
 *
 * Validation:
 * - <what must be true in Elasticsearch for the prompt to be satisfied>
 */

import type { ApmFields } from '@kbn/synthtrace-client';
import { apm, httpExitSpan } from '@kbn/synthtrace-client';
import type { Scenario } from '../../cli/scenario';
import type { RunOptions } from '../../cli/utils/parse_run_cli_flags';
import { getSynthtraceEnvironment } from '../../lib/utils/get_synthtrace_environment';
import { withClient } from '../../lib/utils/with_client';

const ENVIRONMENT = getSynthtraceEnvironment(__filename);

const DEFAULT_SCENARIO_OPTS = {
  rpm: 1,
  // ... add options here
};

function assertNoUnknownScenarioOpts(opts: Record<string, unknown>) {
  const unknown = Object.keys(opts).filter((k) => !(k in DEFAULT_SCENARIO_OPTS));
  if (unknown.length) {
    throw new Error(`Unknown scenarioOpts: ${unknown.join(', ')}`);
  }
}

const scenario: Scenario<ApmFields> = async (runOptions: RunOptions) => {
  const scenarioOpts = (runOptions.scenarioOpts ?? {}) as Record<string, unknown>;
  assertNoUnknownScenarioOpts(scenarioOpts);

  const opts = { ...DEFAULT_SCENARIO_OPTS, ...scenarioOpts } as typeof DEFAULT_SCENARIO_OPTS;

  return {
    generate: ({ range, clients: { apmEsClient } }) => {
      const service = apm
        .service({ name: 'example-service', environment: ENVIRONMENT, agentName: 'nodejs' })
        .instance('instance-a');

      const traces = range.ratePerMinute(opts.rpm).generator((timestamp) => {
        return service
          .transaction({ transactionName: 'GET /example' })
          .timestamp(timestamp)
          .duration(250)
          .success()
          .children(
            service
              .span(
                httpExitSpan({
                  spanName: 'GET downstream',
                  destinationUrl: 'http://downstream:8080',
                })
              )
              .timestamp(timestamp)
              .duration(200)
              .success()
          );
      });

      return withClient(apmEsClient, traces);
    },
  };
};

export default scenario;
```
