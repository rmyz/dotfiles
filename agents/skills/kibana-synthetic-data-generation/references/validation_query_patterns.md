# Validation query patterns (prompt-driven)

Pick validations that directly prove the prompt’s required **data shape** exists (don’t run fixed queries “because we always do”).

## General approach

1. Decide **what must be true** (e.g., “a single trace has \(\ge 60\) unique services”).
2. Choose **where to query** (APM → `traces-apm*`, logs → `logs-*-*`, infra → `metrics-*`).
3. Filter to **recent time** and a **scenario marker**:
   - Prefer `service.environment` (many scenarios set this via `getSynthtraceEnvironment(__filename)`).
   - Otherwise filter by stable markers you set (service prefix, transaction name prefix, log message prefix, dataset).

All examples below are meant to be pasted into **Kibana Dev Tools → Console** and adapted.

## APM: “Is data flowing?”

```json
POST traces-apm*/_search
{
  "size": 0,
  "query": {
    "bool": {
      "filter": [
        { "range": { "@timestamp": { "gte": "now-15m" } } }
      ]
    }
  }
}
```

## APM: service cardinality (inventory / “many services” prompts)

```json
POST traces-apm*/_search
{
  "size": 0,
  "query": {
    "bool": {
      "filter": [
        { "range": { "@timestamp": { "gte": "now-15m" } } },
        { "term": { "service.environment": "<ENVIRONMENT>" } }
      ]
    }
  },
  "aggs": {
    "service_count": { "cardinality": { "field": "service.name" } },
    "top_services": { "terms": { "field": "service.name", "size": 20 } }
  }
}
```

## APM: single trace with many services (trace waterfall “services legend overflow”)

```json
POST traces-apm*/_search
{
  "size": 0,
  "query": {
    "bool": {
      "filter": [
        { "range": { "@timestamp": { "gte": "now-15m" } } },
        { "term": { "service.environment": "<ENVIRONMENT>" } }
      ]
    }
  },
  "aggs": {
    "traces": {
      "terms": { "field": "trace.id", "size": 20 },
      "aggs": {
        "services_in_trace": { "cardinality": { "field": "service.name" } }
      }
    }
  }
}
```

If you need to *prove* one trace crosses a threshold, increase the `terms.size`, or add a pre-filter (service prefix / transaction name) to reduce noise.

## APM: errors present (error-rate / “has failures” prompts)

```json
POST traces-apm*/_search
{
  "size": 0,
  "query": {
    "bool": {
      "filter": [
        { "range": { "@timestamp": { "gte": "now-15m" } } },
        { "term": { "service.environment": "<ENVIRONMENT>" } }
      ]
    }
  },
  "aggs": {
    "events": {
      "terms": { "field": "processor.event", "size": 10 }
    }
  }
}
```

## Logs: docs flowing, split by dataset (logs prompts)

```json
POST logs-*-*/_search
{
  "size": 0,
  "query": {
    "bool": {
      "filter": [
        { "range": { "@timestamp": { "gte": "now-15m" } } }
      ]
    }
  },
  "aggs": {
    "datasets": { "terms": { "field": "data_stream.dataset", "size": 20 } }
  }
}
```

## Infra: docs flowing (hosts/metrics prompts)

```json
POST metrics-*/_search
{
  "size": 0,
  "query": {
    "bool": {
      "filter": [
        { "range": { "@timestamp": { "gte": "now-15m" } } }
      ]
    }
  },
  "aggs": {
    "metricsets": { "terms": { "field": "metricset.name", "size": 20 } },
    "hosts": { "cardinality": { "field": "host.name" } }
  }
}
```
