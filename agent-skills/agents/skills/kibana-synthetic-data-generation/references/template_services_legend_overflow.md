# Template: services legend overflow (single trace, many services)

Use this template when the prompt needs **many distinct services within a single trace** (for example, to force horizontal scrolling in the Trace waterfall services legend).

## Data shape

- **One trace** contains **N unique `service.name` values**.
- Each service has at least one transaction; adjacent services are connected via HTTP exit spans.
- Optional: add extra spans per service to increase “requests” density without increasing trace count.

## Suggested scenario options

- `rpm`: traces per minute (keep low to avoid huge doc counts)
- `numServices`: unique services per trace (e.g. 40–120)
- `serviceNamePrefix`: stable prefix for filtering (e.g. `legend-overflow`)
- `transactionName`: root transaction name (stable for filtering)
- `extraSpansPerService`: add extra non-exit spans per service (default small, e.g. 0–2)

## Core implementation (dynamic scenario)

```ts
import type { ApmFields, Instance } from '@kbn/synthtrace-client';
import { apm, httpExitSpan } from '@kbn/synthtrace-client';
import type { Scenario } from '../../cli/scenario';
import type { RunOptions } from '../../cli/utils/parse_run_cli_flags';
import { getSynthtraceEnvironment } from '../../lib/utils/get_synthtrace_environment';
import { withClient } from '../../lib/utils/with_client';

const ENVIRONMENT = getSynthtraceEnvironment(__filename);

const DEFAULT_SCENARIO_OPTS = {
  rpm: 1,
  numServices: 60,
  serviceNamePrefix: 'legend-overflow',
  transactionName: 'GET /legend-overflow',
  extraSpansPerService: 1,
};

const scenario: Scenario<ApmFields> = async (runOptions: RunOptions) => {
  const opts = { ...DEFAULT_SCENARIO_OPTS, ...(runOptions.scenarioOpts ?? {}) } as typeof DEFAULT_SCENARIO_OPTS;

  const services: Instance[] = [...Array(opts.numServices).keys()].map((i) => {
    const serviceName = `${opts.serviceNamePrefix}-${String(i).padStart(3, '0')}`;
    return apm.service({ name: serviceName, environment: ENVIRONMENT, agentName: 'nodejs' }).instance('instance-a');
  });

  function buildChain(i: number, timestamp: number): ReturnType<Instance['transaction']> {
    const service = services[i];
    const txTimestamp = timestamp + i * 10;

    const tx = service
      .transaction({ transactionName: i === 0 ? opts.transactionName : `svc-${i} ${opts.transactionName}` })
      .timestamp(txTimestamp)
      .duration(250)
      .success();

    const extraSpans = [...Array(opts.extraSpansPerService).keys()].map((k) =>
      service
        .span({ spanName: `custom_operation_${k + 1}`, spanType: 'custom' })
        .timestamp(txTimestamp + 1 + k)
        .duration(25)
        .success()
    );

    if (i === services.length - 1) {
      return tx.children(extraSpans);
    }

    const nextServiceName = services[i + 1].fields['service.name'];

    const exitToNext = service
      .span(
        httpExitSpan({
          spanName: `GET ${nextServiceName}`,
          destinationUrl: `http://${nextServiceName}:8080`,
        })
      )
      .timestamp(txTimestamp + 5)
      .duration(150)
      .success()
      .children(buildChain(i + 1, timestamp));

    return tx.children([...extraSpans, exitToNext]);
  }

  return {
    generate: ({ range, clients: { apmEsClient } }) => {
      const traces = range.ratePerMinute(opts.rpm).generator((timestamp) => buildChain(0, timestamp));
      return withClient(apmEsClient, traces);
    },
  };
};

export default scenario;
```

## Validation idea (pick a query that matches the prompt)

Validate that at least one `trace.id` in the recent time window has a high distinct `service.name` count. Prefer filtering by `service.environment == ENVIRONMENT` (derived from `getSynthtraceEnvironment(__filename)`).

## Run commands

Finite backfill (default):

```sh
node scripts/synthtrace dynamic/<scenarioBaseName> --from now-1w --to now --scenarioOpts='{"rpm":1,"numServices":60}'
```

Manual live run (optional):

```sh
node scripts/synthtrace dynamic/<scenarioBaseName> --live --from now-1w --to now --scenarioOpts='{"rpm":1,"numServices":60}'
```
