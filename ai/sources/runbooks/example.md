# Runbook: Restart Prometheus safely (Docker)
Goal: How to restart Prometheus safely and verify targets are up.

1. Check targets are up in Grafana.
2. Restart Prometheus with `docker restart prometheus`.
3. Validate `/api/v1/targets` shows `up` for `node` and `prometheus`.
