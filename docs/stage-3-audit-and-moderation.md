# Stage 3 Audit Logging and Moderation/Abuse Handling Strategy

This document defines the Stage 3 strategy for registry auditability, abuse response, and moderation workflows.

## Goals

1. Make all sensitive registry mutations traceable.
2. Provide clear moderation workflows for abuse cases.
3. Preserve operational visibility without leaking secrets.

## Events Requiring Audit Logs

At minimum, log these event categories:

- authentication events (`login`, token creation, token revocation)
- publish events (new package versions)
- yank/unyank events
- ownership/team permission changes
- failed authorization events for privileged actions

## Audit Log Record Shape

Each audit event should include:

- event_id (unique)
- timestamp (UTC)
- actor_id (user/service identity)
- actor_type (`user`|`service`)
- action (machine-readable code)
- resource_type (`package`, `version`, `token`, `team`)
- resource_id
- outcome (`success`|`failure`)
- request_id / correlation_id
- ip_address_hash (hashed/pseudonymized for privacy)
- user_agent (optional)
- details (redacted contextual fields)

## Retention and Access Policy

1. Retain audit logs for at least 180 days in hot storage.
2. Archive logs to long-term storage for forensic workflows.
3. Restrict audit log read access to privileged operational roles.
4. Never include raw tokens, auth headers, or secret payloads in log details.

## Moderation and Abuse Workflow

Abuse intake sources:

- automated detection signals
- maintainer/user reports
- operational investigation

Response states:

1. triage: classify severity and scope.
2. contain: temporary package/version freeze or token suspension.
3. investigate: correlate audit events and ownership history.
4. remediate: yank malicious versions, rotate compromised credentials, adjust permissions.
5. communicate: notify affected maintainers/users with next steps.

## Automated Abuse Signals

Initial signal set:

- repeated publish/yank churn in short windows
- suspicious token usage across unusual geographies
- sudden ownership transfer attempts
- repeated failed privileged actions

Signals should trigger review queues, not immediate permanent enforcement without human validation.

## Enforcement Controls

Moderation controls should support:

- package-level freeze
- version-level yank lock
- temporary token disable
- maintainer role suspension

Every enforcement action must produce an audit event with actor and justification metadata.

## Incident Handling Expectations

1. Define on-call ownership for registry abuse incidents.
2. Maintain runbooks for high-severity events (supply chain compromise, credential leak).
3. Support post-incident reviews with timeline reconstruction from audit records.
