# Validation Metrics

Network performance and reliability standards for active deployment.

## Technical

| Metric | Target | Alert Threshold |
|------|------|------|
| Relayer uptime | >= 98% | < 95% |
| API response time | < 1s p95 | > 3s p95 |
| Task completion rate | >= 90% | < 80% |
| Active provider nodes | >= 3 | < 2 |
| Contract call success rate | >= 95% | < 90% |

## User Experience

| Metric | Target | Alert Threshold |
|------|------|------|
| Frontend load time | < 3s | > 8s |
| Wallet connection success | >= 95% | < 90% |
| Provider registration completion | >= 60% | < 40% |
| Task submission success | >= 85% | < 70% |
| Mobile usability score | >= 85 | < 70 |

## Economics

| Metric | Target | Alert Threshold |
|------|------|------|
| Daily task volume | >= 10 | < 3 |
| Value processed during test | >= $1,000 | < $100 |
| Payment settlement success | 100% | < 98% |
| Average settlement time | < 2 min | > 10 min |
| Average provider earnings per day | >= $5 | < $1 |

## Incident Thresholds

### Critical
- Service outage longer than 30 minutes
- Payment failures above 5%
- Security breach or secret exposure
- Data corruption or unrecoverable state

### High
- API response time above 5 seconds
- Task completion rate below 70%
- Active provider count below 2
- Frontend error rate above 5%

### Medium
- Frontend load time above 10 seconds
- Provider registration completion below 30%
- Settlement time above 15 minutes
- Mobile usability below 60

## Review Cadence

1. Check health and task flow daily during the test.
2. Review economics and provider activity weekly.
3. Treat any critical threshold breach as a pause-and-fix event.