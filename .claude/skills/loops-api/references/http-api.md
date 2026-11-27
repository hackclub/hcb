# Loops HTTP API and SDK Reference

## Contents

- Source URLs
- Authentication
- Base URL
- Rate Limits
- Official SDKs
- Endpoints
- Code Examples
- Common Errors
- Tips

## Source URLs

- https://loops.so/docs/api-reference/intro
- https://loops.so/docs/api-reference/examples/campaigns
- https://loops.so/docs/api-reference/examples/transactional-emails
- https://loops.so/docs/sdks/javascript
- https://loops.so/docs/sdks/nuxt
- https://loops.so/docs/sdks/php
- https://loops.so/docs/sdks/ruby
- https://loops.so/docs/webhooks
- https://app.loops.so/openapi.json (OpenAPI 1.22.8)

## Authentication

Every request needs your Loops API key as a Bearer token.

Generate one at: **Settings -> API** in your Loops account.

```
Authorization: Bearer YOUR_API_KEY
```

Never hardcode API keys in source code or expose them client-side. Always load from environment variables or a secrets manager. The Loops API requires server-side requests. Browser-side calls will hit CORS errors by design.

```bash
export LOOPS_API_KEY="your-api-key-here"
```

## Base URL

```
https://app.loops.so/api
```

## Rate Limits

**10 requests per second per team.** Responses include `x-ratelimit-limit` and `x-ratelimit-remaining` headers. On limit, you will get HTTP 429, so implement exponential backoff retries.

## Official SDKs

Use an official SDK when the user's language has one:

- **JavaScript/TypeScript**: `npm install loops`
- **Go**: `go get github.com/loops-so/loops-go`
- **Nuxt**: `npm install nuxt-loops`
- **PHP**: `composer require loops-so/loops`
- **Ruby**: `gem install loops_sdk`

If the user is working from the shell instead of application code, use the separate `loops-cli` skill.

---

## Endpoints

### Test API key

```
GET /v1/api-key
```

Returns `{ success: true, teamName: "..." }` on success. Use this to confirm credentials are working.

### Contacts

#### Create a contact

```
POST /v1/contacts/create
```

```jsonc
{
  "email": "user@example.com",
  "firstName": "Alex",
  "lastName": "Chen",
  "subscribed": true,
  "userGroup": "premium",
  "userId": "usr_123",
  "mailingLists": { "cm06f5v0e45nf0ml5754o9cix": true },
  "customProperty": "value"
}
```

Returns `{ success: true, id: "cct42l54f20i1la0lfooe3z12" }`.
Returns `409` if `email` or `userId` already exists. Use `PUT /v1/contacts/update` instead.

#### Update a contact

```
PUT /v1/contacts/update
```

Same body shape as create. Include `email` or `userId` to identify the contact. This works as an upsert, so if the contact does not exist it will be created.

If you need to change a contact's email address, the contact must already have a `userId`. Send the update request with that `userId` and the new `email` value.

#### Find a contact

```
GET /v1/contacts/find?email=user%40example.com
GET /v1/contacts/find?userId=usr_123
```

Only one parameter is allowed. Email must be URI-encoded.

```json
[
  {
    "id": "...",
    "email": "user@example.com",
    "firstName": "Alex",
    "lastName": "Chen",
    "source": "api",
    "subscribed": true,
    "userGroup": "premium",
    "userId": "usr_123",
    "mailingLists": { "cm06f5v0e45nf0ml5754o9cix": true },
    "optInStatus": "accepted"
  }
]
```

#### Delete a contact

```
POST /v1/contacts/delete
```

```json
{
  "email": "user@example.com"
}
```

Provide exactly one of `email` or `userId`, not both.

#### Contact suppression status and removal

```
GET /v1/contacts/suppression?email=user%40example.com
GET /v1/contacts/suppression?userId=usr_123
DELETE /v1/contacts/suppression?email=user%40example.com
DELETE /v1/contacts/suppression?userId=usr_123
```

Use the `GET` endpoint to inspect suppression state and current removal quota (`limit` and `remaining`).
Use the `DELETE` endpoint to remove a suppressed contact by `email` or `userId`.
Both endpoints require exactly one identifier (`email` or `userId`).

### Contact Properties

#### List properties

```
GET /v1/contacts/properties?list=all
```

`list` can be `"all"` (default) or `"custom"`.

Returns `[{ key, label, type }]`.

#### Create a property

```
POST /v1/contacts/properties
```

```jsonc
{
  "name": "planTier",
  "type": "string"
}
```

Custom property names should be camelCase. Valid types are `"string"`, `"number"`, `"boolean"`, and `"date"`.

### Mailing Lists

#### List mailing lists

```
GET /v1/lists
```

Returns `[{ id, name, description, isPublic }]`. Use the `id` values in `mailingLists` objects.

### Audience Segments

Audience segments are saved audience filters. Use them to target draft campaigns or workflow audience-filter nodes via `audienceSegmentId`.

#### List audience segments

```
GET /v1/audience-segments?perPage=20&cursor=...
```

`perPage` must be between 10 and 50 (default 20). Returns paginated `data` with `id`, `name`, `description`, `filter`, and timestamps, most recently created first.

#### Get an audience segment

```
GET /v1/audience-segments/{audienceSegmentId}
```

Returns the segment metadata and its `filter` tree (same shape as `audienceFilter` on campaigns).

#### Create an audience segment

```
POST /v1/audience-segments
```

```jsonc
{
  "name": "Active users",
  "description": "Opened a campaign in the last 30 days",
  "filter": {
    "match": "all",
    "conditions": [
      {
        "type": "property",
        "key": "planTier",
        "operator": "equals",
        "value": "pro"
      }
    ]
  }
}
```

`name` and `filter` are required. `name` must be unique within the team (max 255 chars). `description` is optional (max 1000 chars). Filter shape matches campaign `audienceFilter`. Returns `400` for invalid bodies, duplicate names, or filters with too many conditions. Returns `404` if the filter references a campaign, workflow, or workflow email that does not exist.

### Workflows

Workflows are Loops automations (triggered emails, timers, branches, experiments, and more). The workflow API can list, create, and mutate workflow graphs and nodes. The workflow API must be enabled for your team; otherwise these endpoints return `401`.

#### Revision tokens and queued contacts

Most workflow mutations require `expectedRevisionId` matching the latest `workflowRevisionId` from a read or mutation. Older workflows may return `workflowRevisionId: null` until their first revision-aware mutation — pass `null` back as `expectedRevisionId` in that case. Stale tokens return `409 Conflict`.

Destructive changes (delete nodes, change mailing list) can discard contacts queued in the workflow:

- Default `queuedContactPolicy` is `"fail"`. If queued contacts would be removed, the API returns `"status": "queuedContactsFound"` instead of mutating.
- Retry with `queuedContactPolicy: "discard"` to apply the change and discard those contacts.
- Use `dryRun: true` to preview impact without mutating.

Public workflows are limited to **400 nodes**. Generated children count toward that limit.

#### Typical workflow build sequence

1. `POST /v1/workflows` with a name (optional `workflowGroupId`; defaults to Unsorted) — creates a draft with a blank trigger and exit node; save `id` and `workflowRevisionId`.
2. Optionally set `mailingListId` via `POST /v1/workflows/{workflowId}/mailing-list`.
3. Configure the trigger with `POST /v1/workflows/{workflowId}/nodes/{nodeId}` (for event triggers, use `GET /v1/event-patterns` first).
4. Insert nodes with `POST /v1/workflows/{workflowId}/nodes` (`insertMode: "between"`, `"before"`, or `"after"`), then update each node's config.
5. For `SendEmailAction` nodes, edit email content via `POST /v1/email-messages/{emailMessageId}` using the returned `emailMessageId`.
6. Always pass the latest `workflowRevisionId` as `expectedRevisionId` on the next mutation.

#### List workflows

```
GET /v1/workflows?perPage=20&cursor=...
```

`perPage` must be between 10 and 50 (default 20). Returns paginated `data` with `id`, `url`, `name`, `workflowGroupId`, `createdAt`, and `updatedAt`.

```json
{
  "pagination": {
    "totalResults": 12,
    "returnedResults": 12,
    "perPage": 20,
    "totalPages": 1,
    "nextCursor": null,
    "nextPage": null
  },
  "data": [
    {
      "id": "cwf42l54f20i1la0lfooe3z12",
      "url": "https://app.loops.so/workflows/cwf42l54f20i1la0lfooe3z12",
      "name": "Onboarding drip",
      "workflowGroupId": "cwg42l54f20i1la0lfooe3z12",
      "createdAt": "2025-02-02T02:56:28.845Z",
      "updatedAt": "2025-02-10T14:30:00.000Z"
    }
  ]
}
```

Returns `400` for invalid `perPage` or `cursor` values.

#### Create a workflow

```
POST /v1/workflows
```

```jsonc
{
  "name": "Onboarding drip",
  "description": "Welcome new signups",
  "mailingListId": "cm06f5v0e45nf0ml5754o9cix",
  "workflowGroupId": "cwg42l54f20i1la0lfooe3z12"
}
```

`name` is required. `description`, `mailingListId`, and `workflowGroupId` are optional (`mailingListId` may be `null`). When `workflowGroupId` is omitted, the workflow is added to the team's Unsorted group. Creates a draft workflow with a blank trigger and exit node. Returns a `SimplifiedWorkflow` including `url` and `workflowGroupId`. After creation, change the mailing list with `/v1/workflows/{workflowId}/mailing-list`. Returns `400` if the workflow group is not found.

#### Get a workflow

```
GET /v1/workflows/{workflowId}
```

Returns a simplified workflow graph with `id`, `url`, `workflowRevisionId`, `status`, `name`, `description`, `workflowGroupId`, `mailingListId`, `rootNodeId`, and a `nodes` map keyed by node ID.

`status` is one of `Draft`, `Sending`, `Paused`, or `PausedAndQueueing`.

Each node includes `typeName` and `nextNodeIds`. Supported `typeName` values:

- **Triggers**: `SignupTrigger`, `EventTrigger` (`eventName`, `reEligible`), `ContactPropertyTrigger` (`contactPropertyQuery`, `reEligible`), `AddToListTrigger` (`mailingListId`, `reEligible`), `BlankTrigger`
- **Actions and logic**: `AudienceFilter`, `TimerAction` (`amount`, `unit`), `SendEmailAction` (`emailMessageId`, `subject`), `ExitAction`, `BranchNode`, `ExperimentBranchNode` (`samplingRate`), `VariantNode` (`isControl`)

`TimerAction` `unit` values are `m` (minutes), `h` (hours), and `d` (days). Set `amount` to `0` to move to the next node immediately. `reEligible` matches the UI "Trigger frequency" option: `true` allows re-entry on every match; `false` means contacts enter once.

Use `GET /v1/workflows/{workflowId}/nodes/{nodeId}` for full node detail.

```jsonc
{
  "id": "cwf42l54f20i1la0lfooe3z12",
  "url": "https://app.loops.so/workflows/cwf42l54f20i1la0lfooe3z12",
  "workflowRevisionId": "crv42l54f20i1la0lfooe3z99",
  "status": "Draft",
  "name": "Onboarding drip",
  "description": "Welcome new signups",
  "workflowGroupId": "cwg42l54f20i1la0lfooe3z12",
  "mailingListId": "cm06f5v0e45nf0ml5754o9cix",
  "rootNodeId": "cf16k73gq014h3mmj5b6jdi9r",
  "nodes": {
    "cf16k73gq014h3mmj5b6jdi9r": {
      "typeName": "EventTrigger",
      "nextNodeIds": ["cf16k73gq014h3mmj5b4jdifg"],
      "eventName": "signup",
      "reEligible": false
    },
    "cf16k73gq014h3mmj5b4jdifg": {
      "typeName": "TimerAction",
      "nextNodeIds": ["cf16k73gq014h3mmj5b4jdifh"],
      "amount": 1,
      "unit": "d"
    },
    "cf16k73gq014h3mmj5b4jdifh": {
      "typeName": "SendEmailAction",
      "nextNodeIds": ["cf16k73gq014h3mmj5b4jdixi"],
      "emailMessageId": "cem42l54f20i1la0lfooe3z12",
      "subject": "Welcome aboard"
    },
    "cf16k73gq014h3mmj5b4jdixi": {
      "typeName": "ExitAction",
      "nextNodeIds": []
    }
  }
}
```

Returns `400` for an invalid `workflowId`. Returns `404` if the workflow is not found.

#### Update a workflow

```
POST /v1/workflows/{workflowId}
```

Updates display properties and group. At least one of `name`, `description`, or `workflowGroupId` must be provided. To change the mailing list, use `/v1/workflows/{workflowId}/mailing-list` instead (mailing-list changes may remove queued contacts).

```jsonc
{
  "expectedRevisionId": "crv42l54f20i1la0lfooe3z99",
  "name": "Onboarding drip v2",
  "description": "Updated welcome sequence",
  "workflowGroupId": "cwg42l54f20i1la0lfooe3z12"
}
```

Returns the updated `SimplifiedWorkflow`. Returns `409` if `expectedRevisionId` is stale.

#### Delete a workflow

```
DELETE /v1/workflows/{workflowId}
```

```jsonc
{
  "expectedRevisionId": "crv42l54f20i1la0lfooe3z99"
}
```

Successful deletion returns `204 No Content`. Deleted workflows are not returned by other endpoints (`GET` returns `404`).

If the workflow is currently sending or has queued contacts, the API returns `409 Conflict` with a `message` instead of deleting. Retry with the same `expectedRevisionId` and `confirmDelete: true` to delete the workflow, stop sending, and cancel queued contacts.

```jsonc
{
  "expectedRevisionId": "crv42l54f20i1la0lfooe3z99",
  "confirmDelete": true
}
```

#### Workflow groups

Organize workflows into groups. Same shape as campaign groups and transactional groups. The reserved name `"Unsorted"` cannot be used when creating or renaming groups, and the Unsorted group cannot be edited.

```
GET /v1/workflow-groups?perPage=20&cursor=...
POST /v1/workflow-groups
GET /v1/workflow-groups/{workflowGroupId}
POST /v1/workflow-groups/{workflowGroupId}
```

Create body:

```jsonc
{
  "name": "Onboarding",
  "description": "Top of funnel"
}
```

Update body (at least one field required):

```jsonc
{
  "name": "Activation",
  "description": "Updated description"
}
```

List and get responses return `id`, `name`, `description`, and timestamps.

#### Change workflow mailing list

```
POST /v1/workflows/{workflowId}/mailing-list
```

```jsonc
{
  "expectedRevisionId": "crv42l54f20i1la0lfooe3z99",
  "mailingListId": "cm16k73gq014h0mmj5b6jdi9r",
  "dryRun": true,
  "queuedContactPolicy": "fail"
}
```

`mailingListId` is required and may be `null` to clear the list. Clearing does not discard queued contacts. Assigning a new list can return `"status": "queuedContactsFound"`; retry with `queuedContactPolicy: "discard"` to apply.

Success responses are one of:

- `{ "status": "dryRun" | "queuedContactsFound", "mailingListId", "queuedContactCount", "queuedContactLimitReached" }`
- `{ "status": "updated", "mailingListId", "workflowRevisionId", "queuedContactCount", "queuedContactLimitReached" }`

#### Create a workflow node

```
POST /v1/workflows/{workflowId}/nodes
```

Creates a new default node and returns it with the latest workflow. Choose placement with `insertMode`:

- `between` — place between an existing `fromNodeId` → `toNodeId` connection
- `before` — place before `toNodeId` (target must have a parent and cannot be a trigger). `VariantNode` cannot use `before`; restore a missing variant with `between` from the experiment branch. Deprecated `beforeNodeId` is still accepted; new callers should use `toNodeId`.
- `after` — place after `fromNodeId` when that node has exactly one outgoing connection. Invalid when `fromNodeId` has no outgoing nodes, multiple outgoing nodes, or is an exit node. For multi-output nodes, use `between` with the exact `toNodeId`.

Creatable `nodeTypeName` values: `AudienceFilter`, `BranchNode`, `ExperimentBranchNode`, `TimerAction`, `SendEmailAction`, `VariantNode`. Trigger nodes and `ExitAction` cannot be created via the API.

New nodes start with defaults; update them after creation. Branch creates also spawn children:

- `BranchNode` creates two `AudienceFilter` children (adds 3 nodes total)
- `ExperimentBranchNode` creates two regular `VariantNode` children plus one control `VariantNode` (adds 4 nodes total)

A workflow cannot be started unless each direct `BranchNode` child is an `AudienceFilter`. For experiments, use create-node only to insert a missing `VariantNode` before non-variant content; use add-branch for another variant path. When `fromNodeId` is an `ExperimentBranchNode`, `nodeTypeName` must be `VariantNode` and `toNodeId` cannot already be a `VariantNode`.

To add another branch under an existing branch/experiment node, use `/nodes/{nodeId}/add-branch` instead.

```jsonc
{
  "expectedRevisionId": "crv42l54f20i1la0lfooe3z99",
  "insertMode": "between",
  "nodeTypeName": "TimerAction",
  "fromNodeId": "cf16k73gq014h3mmj5b6jdi9r",
  "toNodeId": "cf16k73gq014h3mmj5b4jdixi"
}
```

```jsonc
{
  "expectedRevisionId": "crv42l54f20i1la0lfooe3z99",
  "insertMode": "before",
  "nodeTypeName": "SendEmailAction",
  "toNodeId": "cf16k73gq014h3mmj5b4jdixi"
}
```

```jsonc
{
  "expectedRevisionId": "crv42l54f20i1la0lfooe3z99",
  "insertMode": "after",
  "nodeTypeName": "TimerAction",
  "fromNodeId": "cf16k73gq014h3mmj5b6jdi9r"
}
```

Response shape: `{ "node": { ...createdNode, "workflowRevisionId", "createdChildNodes"? }, "workflow": SimplifiedWorkflow }`.

#### Add a branch

```
POST /v1/workflows/{workflowId}/nodes/{nodeId}/add-branch
```

Adds one child under an existing `BranchNode` or `ExperimentBranchNode`:

- Under `BranchNode` → creates one `AudienceFilter`
- Under `ExperimentBranchNode` → creates one `VariantNode`

```jsonc
{
  "expectedRevisionId": "crv42l54f20i1la0lfooe3z99"
}
```

Does not accept node configuration fields; update the child afterward. Adds 1 node toward the 400-node cap. Returns `{ "node": ..., "workflow": ... }`.

#### Reroute a node connection

```
POST /v1/workflows/{workflowId}/nodes/{nodeId}/reroute
```

Moves the source node's only outgoing connection to another valid target. Send the source node in the URL path and the new target in the body.

The source node must have exactly one outgoing connection. `BranchNode` and `ExperimentBranchNode` cannot be rerouted (they have multiple outputs). The current target must still have another incoming connection after the reroute. The workflow cannot be edited while in a `Sending` state.

```jsonc
{
  "expectedRevisionId": "crv42l54f20i1la0lfooe3z99",
  "newTargetNodeId": "cf16k73gq014h3mmj5b4jdifh"
}
```

Returns the updated source node plus the latest workflow. Returns `400` for invalid connection selection, reroute target, or workflow state. Returns `409` if `expectedRevisionId` is stale.

#### Get a workflow node

```
GET /v1/workflows/{workflowId}/nodes/{nodeId}
```

Returns full detail for a single node plus `workflowRevisionId`. All node types include `id`, `workflowId`, `typeName`, and `nextNodeIds`. Type-specific fields:

- **`EventTrigger`**: `eventName`, `eventProperties` (array of `{ name, type }` where `type` is `string`, `number`, `boolean`, or `date`), `reEligible`
- **`ContactPropertyTrigger`**: `contactPropertyQuery`, `reEligible`
- **`AddToListTrigger`**: `mailingListId`, `reEligible`
- **`AudienceFilter`**: `audienceFilter`, `audienceSegmentId`, `appliesDownstream`
- **`TimerAction`**: `amount`, `unit`
- **`SendEmailAction`**: `emailMessageId`, `subject`
- **`ExperimentBranchNode`**: `samplingRate` (0–100; percentage sent to variant branches; remainder goes to control; `100` sends all to variants)
- **`VariantNode`**: `isControl`

`contactPropertyQuery` compares a contact property with `key`, `is`, and `was` comparisons. Each comparison has `operator` and `value`. In updates, `key` must resolve to an existing contact property available for Contact Updated triggers (hidden/unsupported fields like `createdAt`, `notes`, and computed properties are rejected).

`was` can use any operator for the property type. `is` uses the same operators except number and boolean properties cannot use `empty`. Operators by type:

- **String**: `any`, `equal`, `not_equal`, `contains`, `not_contains`, `empty`, `not_empty`
- **Number**: `any`, `greater_than`, `less_than`, `numeric_equal`, `numeric_not_equal`, `empty`, `not_empty`
- **Boolean**: `any`, `true`, `false`, `empty`, `not_empty`
- **Date**: `any`, `empty`, `not_empty`, `after`, `before`, `between`

`appliesDownstream` on `AudienceFilter` matches the UI "Filter scope" option: `true` applies to all downstream nodes; `false` applies only to the current node.

Returns `400` for invalid IDs. Returns `404` if the workflow or node is not found.

##### Get workflow node metrics

```
GET /v1/workflows/{workflowId}/nodes/{nodeId}/metrics
```

Returns all-time engagement counters for a `SendEmailAction` node: `sends`, `opens`, `clicks`, `unsubscribes`, `spamReports`, `hardBounces`, `softBounces`. Opens and clicks count sends, not events (a send opened five times counts once). Returns `400` for any other node type, or if the node has no email message. A `SendEmailAction` that has not sent yet reports every counter as `0`.

#### Update a workflow node

```
POST /v1/workflows/{workflowId}/nodes/{nodeId}
```

Updates workflow-node-owned fields. Shared resources (email messages, audience segments) should be updated through their own APIs. Trigger updates may include `typeName` to change one trigger type to another.

```jsonc
{
  "expectedRevisionId": "crv42l54f20i1la0lfooe3z99",
  "payload": {
    "typeName": "EventTrigger",
    "eventName": "signup",
    "reEligible": false
  }
}
```

Payload shapes by node type (all fields optional within each payload except where noted; at least one field required):

| Node | Payload fields |
| --- | --- |
| `SignupTrigger` | `typeName: "SignupTrigger"` (required when switching to this type) |
| `EventTrigger` | `typeName?`, `eventPatternId` or `eventName` (not both; set either to `null` to clear), `reEligible?` |
| `ContactPropertyTrigger` | `typeName?`, `contactPropertyQuery?`, `reEligible?` |
| `AddToListTrigger` | `typeName?`, `reEligible?` |
| `AudienceFilter` | `audienceSegmentId?`, `audienceFilter?`, `appliesDownstream?` |
| `TimerAction` | `amount?`, `unit?` |
| `ExperimentBranchNode` | `samplingRate?` |
| `VariantNode` | `isControl?` (`true` makes this the control and clears the previous control) |

`SendEmailAction`, `BranchNode`, `BlankTrigger`, and `ExitAction` are not updated through this payload set (email content via `/v1/email-messages/{emailMessageId}`). Returns `501` if a node update is not implemented. Returns `409` if `expectedRevisionId` is stale.

#### Delete a workflow node

```
DELETE /v1/workflows/{workflowId}/nodes/{nodeId}
```

```jsonc
{
  "expectedRevisionId": "crv42l54f20i1la0lfooe3z99",
  "dryRun": true,
  "queuedContactPolicy": "fail"
}
```

If contacts are queued at the node, returns `"status": "queuedContactsFound"` instead of deleting. Retry with `queuedContactPolicy: "discard"` to delete and discard those contacts.

#### Delete workflow nodes recursively

```
DELETE /v1/workflows/{workflowId}/nodes/{nodeId}/recursive
```

Deletes a node and its downstream subtree. Same request body and queued-contact behavior as single-node delete. If contacts are queued at any node that would be deleted, returns `"status": "queuedContactsFound"`.

Delete responses are one of:

- `{ "status": "dryRun" | "queuedContactsFound", "nodeIds", "queuedContactCount", "queuedContactLimitReached" }`
- `{ "status": "deleted", "nodeIds", "workflowRevisionId", "queuedContactCount", "queuedContactLimitReached" }`

### Event Patterns

Event patterns are used by workflow `EventTrigger` nodes. The workflow API beta must be enabled; otherwise these endpoints return `401`.

#### List event patterns

```
GET /v1/event-patterns?perPage=20&cursor=...
```

`perPage` must be between 10 and 50 (default 20). Returns paginated summaries with `id`, `eventName`, and `incomingWebhookPlatform` (`clerk`, `polar`, `stripe`, `supabase`, or `null` for custom events).

#### Get an event pattern by ID

```
GET /v1/event-patterns/{eventPatternId}
```

Returns `id`, `eventName`, `eventProperties` (`{ name, type }[]`), and `incomingWebhookPlatform`.

#### Get an event pattern by name

```
GET /v1/event-patterns/by-name/{eventName}
```

Same response as get-by-ID. Event names are case-sensitive (`PaymentReceived` ≠ `paymentReceived`) and should be URL-encoded if they contain special characters.

### Dedicated Sending IPs

#### List dedicated sending IP addresses

```
GET /v1/dedicated-sending-ips
```

Example response:

```json
["1.2.3.4", "5.6.7.8"]
```

### Events

#### Send an event

```
POST /v1/events/send
```

Events trigger email automations configured in Loops. The event name must match the configured trigger exactly.

```jsonc
{
  "email": "user@example.com",
  "userId": "usr_123",
  "eventName": "signup",
  "eventProperties": {
    "plan": "pro",
    "trialDays": 14
  },
  "mailingLists": { "cm06f5v0e45nf0ml5754o9cix": true },
  "firstName": "Alex"
}
```

Fields inside `eventProperties` are scoped to the event. Top-level fields like `firstName` update the contact record permanently.

To avoid duplicate sends on retries, pass an idempotency key:

```
Idempotency-Key: unique-id-max-100-chars
```

Returns `409` if the same key was used before.

### Transactional Emails

#### Send a transactional email

```
POST /v1/transactional
```

```jsonc
{
  "email": "user@example.com",
  "transactionalId": "cll42l54f20i1la0lfooe3z12",
  "addToAudience": true,
  "dataVariables": {
    "firstName": "Alex",
    "resetLink": "https://..."
  },
  "attachments": [
    {
      "filename": "invoice.pdf",
      "contentType": "application/pdf",
      "data": "<base64-encoded-content>"
    }
  ]
}
```

`email` and `transactionalId` are required. `addToAudience: true` creates a contact from `email` if one does not already exist.

Attachments must be enabled on your account before use. Contact `help@loops.so` to enable them.

Supports the `Idempotency-Key` header (max 100 characters) the same way as events. Returns `400` if the transactional email is not published.

#### List transactional emails

```
GET /v1/transactional-emails?perPage=20&cursor=...
```

Preferred endpoint. Returns a paginated list of transactional emails, most recently created first. `perPage` must be between 10 and 50. Default is 20. Use this to find `transactionalId` values and inspect draft/published state.

```json
{
  "pagination": {
    "totalResults": 42,
    "returnedResults": 20,
    "perPage": 20,
    "totalPages": 3,
    "nextCursor": "clx42l54f20i1la0lfooe3z12",
    "nextPage": "https://..."
  },
  "data": [
    {
      "id": "cll42l54f20i1la0lfooe3z12",
      "url": "https://app.loops.so/transactional/cll42l54f20i1la0lfooe3z12",
      "name": "Welcome email",
      "draftEmailMessageId": null,
      "publishedEmailMessageId": "cem42l54f20i1la0lfooe3z12",
      "transactionalGroupId": "ctg42l54f20i1la0lfooe3z12",
      "createdAt": "2025-02-02T02:56:28.845Z",
      "updatedAt": "2025-02-02T03:10:00.000Z",
      "dataVariables": ["firstName", "trialEnd"]
    }
  ]
}
```

`dataVariables` lists variable names from the published email. It is empty for unpublished transactional emails.

Legacy (deprecated):

```
GET /v1/transactional?perPage=20&cursor=...
```

Returns only published transactional emails with `id`, `name`, `lastUpdated`, and `dataVariables`. Prefer `GET /v1/transactional-emails`.

#### Creating and managing transactional emails

The API lets you create transactional email templates, edit their draft content, and publish them from code.

A sending domain must be configured before creating transactional emails or editing drafts.

For LMX markup rules, use the separate `loops-lmx` skill.

##### Typical workflow

1. `POST /v1/transactional-emails` with `{ "name": "..." }` — creates the transactional email and an empty draft email message. Save `id`, `draftEmailMessageId`, and `draftEmailMessageContentRevisionId`.
2. `GET /v1/themes` and `GET /v1/components`, then `GET /v1/themes/{themeId}` and `GET /v1/components/{componentId}` for likely matches.
3. `POST /v1/email-messages/{draftEmailMessageId}` — set subject, sender fields, and `lmx`; pass `draftEmailMessageContentRevisionId` as `expectedRevisionId` on the first update.
4. After each successful update, save the returned `contentRevisionId` and pass it as `expectedRevisionId` on the next update.
5. `POST /v1/transactional-emails/{transactionalId}/publish` — publish the draft. The draft becomes the published version and the draft is cleared.
6. `POST /v1/transactional` — send the published email using the returned `id` as `transactionalId`.

To edit a published transactional email later, call `POST /v1/transactional-emails/{transactionalId}/draft` to ensure a draft exists (seeded from the published version when present), update the draft via `/v1/email-messages/{emailMessageId}`, then publish again.

##### Create a transactional email

```
POST /v1/transactional-emails
```

```jsonc
{
  "name": "Welcome email"
}
```

Returns `201` with `id`, `url`, `draftEmailMessageId`, `draftEmailMessageContentRevisionId`, `publishedEmailMessageId` (null until published), `transactionalGroupId`, timestamps, and `dataVariables`.

##### Get a transactional email

```
GET /v1/transactional-emails/{transactionalId}
```

Returns `id`, `url`, `name`, `draftEmailMessageId`, `publishedEmailMessageId`, `transactionalGroupId`, timestamps, and `dataVariables`.

##### Get transactional email metrics

```
GET /v1/transactional-emails/{transactionalId}/metrics
```

Returns all-time delivery counters totalled across every published version: `sends`, `deliveries`, `spamReports`, `hardBounces`, `softBounces`.

##### Update a transactional email

```
POST /v1/transactional-emails/{transactionalId}
```

```jsonc
{
  "name": "Renamed welcome email",
  "transactionalGroupId": "ctg42l54f20i1la0lfooe3z12"
}
```

Updates the transactional email name and/or group.

##### Ensure a draft email message

```
POST /v1/transactional-emails/{transactionalId}/draft
```

If a draft already exists, returns it unchanged. Otherwise creates a new empty draft, seeded from the most recent published version when present. Returns `draftEmailMessageId` and `draftEmailMessageContentRevisionId` for editing via `/v1/email-messages/{emailMessageId}`.

##### Publish a transactional email draft

```
POST /v1/transactional-emails/{transactionalId}/publish
```

Publishes the current draft. Returns `409` if there is no draft to publish. Returns `422` if the draft fails validation, the sending domain is not verified, or content was flagged as unsafe.

##### Transactional groups

Organize transactional emails into groups. The reserved name `"Unsorted"` cannot be used when creating or renaming groups, and the Unsorted group cannot be edited.

```
GET /v1/transactional-groups?perPage=20&cursor=...
POST /v1/transactional-groups
GET /v1/transactional-groups/{transactionalGroupId}
POST /v1/transactional-groups/{transactionalGroupId}
```

Create body:

```jsonc
{
  "name": "Onboarding",
  "description": "Signup and welcome flows"
}
```

Update body (at least one field required):

```jsonc
{
  "name": "Renamed group",
  "description": "Updated description"
}
```

List and get responses return `id`, `name`, `description`, and timestamps.

### Creating and editing campaigns

The API lets you create draft campaigns and set email-message content (subject, sender, preview text, LMX) from code. You can also set the campaign group, audience (mailing list, segment, or inline filter), and scheduling on create or while the campaign is still a draft.

A sending domain must be configured before creating campaigns or reading email messages. Campaign and email-message writes only work while the campaign is in **Draft** status.

For LMX markup rules and design guidance, use the separate `loops-lmx` skill. Copy/paste workflow examples: [Campaigns API examples](https://loops.so/docs/api-reference/examples/campaigns).

#### Typical workflow

1. Optionally `GET /v1/campaign-groups`, `GET /v1/audience-segments`, and `GET /v1/lists` to discover group, segment, and mailing-list IDs.
2. `POST /v1/campaigns` with `{ "name": "..." }` and optional `campaignGroupId`, `mailingListId`, `audienceSegmentId`, `audienceFilter`, or `scheduling` — saves `id`, `emailMessageId`, and `emailMessageContentRevisionId`.
3. `GET /v1/themes` and `GET /v1/components`, then `GET /v1/themes/{themeId}` and `GET /v1/components/{componentId}` for likely matches.
4. `POST /v1/email-messages/{emailMessageId}` — set subject, sender fields, and `lmx`; pass `emailMessageContentRevisionId` as `expectedRevisionId` on the first update.
5. After each successful update, save the returned `contentRevisionId` and pass it as `expectedRevisionId` on the next update to avoid `409 Conflict` from stale revisions.
6. Optionally `POST /v1/email-messages/{emailMessageId}/preview` to send a test preview before scheduling or sending from the dashboard.

#### Audience targeting

A draft campaign can be sent to different audience types:

- **`mailingListId`** — send to a mailing list (`GET /v1/lists` for IDs).
- **`audienceSegmentId`** — send to a saved segment (`GET /v1/audience-segments`).
- **`audienceFilter`** — inline filter conditions (same tree shape as segment `filter`).

All three options can be used together. If a mailing list is applied, the segment/filter is applied within that mailing list. If a filter is used with a segment, the filter is applied on top of the segment's saved filter — contacts must match both. 

`audienceFilter` is a tree of conditions combined with `match: "all"` or `match: "any"`:

```jsonc
{
  "match": "all",
  "conditions": [
    {
      "type": "property",
      "key": "planTier",
      "operator": "equals",
      "value": "pro"
    },
    {
      "type": "optIn",
      "status": "accepted"
    },
    {
      "type": "activity",
      "action": "opened",
      "negate": false,
      "target": "campaign",
      "id": "ccm42l54f20i1la0lfooe3z12"
    },
    {
      "type": "activity",
      "action": "clicked",
      "negate": false,
      "target": "workflowEmail",
      "id": "cem52l54f20i1la0lfooe3z12"
    }
  ]
}
```

Property `operator` values include `any`, `contains`, `notContains`, `equals`, `notEquals`, `greaterThan`, `lessThan`, `isTrue`, `isFalse`, `empty`, `notEmpty`, `dateEmpty`, `dateNotEmpty`, `after`, `before`, and `between` (use `{ "from": "...", "to": "..." }` for `between`). Omit `value` for value-less operators like `isTrue` or `empty`.

Activity conditions use `action` (`sent`, `opened`, or `clicked`), `negate`, `target` (`campaign`, `workflow`, or `workflowEmail`), and `id` (the campaign, workflow, or workflow email ID).

#### Scheduling

```jsonc
{
  "scheduling": {
    "method": "schedule",
    "timestamp": "2026-06-22T14:00:00.000Z"
  }
}
```

`method` is `"now"` or `"schedule"`. When `method` is `"schedule"`, `timestamp` is required and must be in the future. Omit `timestamp` when `method` is `"now"`.

#### Campaign groups

Organize campaigns into groups. The reserved name `"Unsorted"` cannot be used when creating or renaming groups, and the Unsorted group cannot be edited.

```
GET /v1/campaign-groups?perPage=20&cursor=...
POST /v1/campaign-groups
GET /v1/campaign-groups/{campaignGroupId}
POST /v1/campaign-groups/{campaignGroupId}
```

Create body:

```jsonc
{
  "name": "Product updates",
  "description": "Feature announcements"
}
```

Update body (at least one field required):

```jsonc
{
  "name": "Renamed group",
  "description": "Updated description"
}
```

List and get responses return `id`, `name`, `description`, and timestamps.

#### Campaigns

##### List campaigns

```
GET /v1/campaigns?perPage=20&cursor=...
```

`perPage` must be between 10 and 50 (default 20). Returns paginated `data` with `id`, `url`, `emailMessageId`, `name`, `status`, `campaignGroupId`, `mailingListId`, `audienceSegmentId`, `audienceFilter`, `scheduling`, and timestamps. Status values include `Draft`, `Scheduled`, `Sending`, and `Sent`.

##### Create a campaign

```
POST /v1/campaigns
```

Only `name` is required. Creates a draft campaign and an empty email message in one request. When `campaignGroupId` is omitted, the campaign is added to the team's Unsorted group.

```jsonc
{
  "name": "Spring product announcement",
  "campaignGroupId": "ccg42l54f20i1la0lfooe3z12",
  "mailingListId": "cm06f5v0e45nf0ml5754o9cix",
  "audienceSegmentId": null,
  "audienceFilter": null,
  "scheduling": {
    "method": "now"
  }
}
```

Returns `201` with `id`, `url`, `emailMessageId`, `emailMessageContentRevisionId`, `campaignGroupId`, audience fields, `scheduling`, and timestamps. Save the campaign `id`, `emailMessageId`, and `emailMessageContentRevisionId` for subsequent updates.

Returns `404` if a referenced mailing list or audience segment is not found. Returns `400` if the campaign group is not found or no sending domain is configured.

##### Get a campaign

```
GET /v1/campaigns/{campaignId}
```

Returns `id`, `url`, `name`, `status`, `emailMessageId`, `campaignGroupId`, `mailingListId`, `audienceSegmentId`, `audienceFilter`, `scheduling`, and timestamps.

##### Get campaign metrics

```
GET /v1/campaigns/{campaignId}/metrics
```

Returns all-time engagement counters for a **sent** campaign: `sends`, `opens`, `clicks`, `unsubscribes`, `spamReports`, `hardBounces`, `softBounces`. Opens and clicks count sends, not events. Returns `400` if the campaign has not been sent yet or has no email message.

##### Update a campaign

```
POST /v1/campaigns/{campaignId}
```

Updates a draft campaign. At least one field is required. Returns `409` if the campaign is not in draft status. Returns `404` if the campaign, mailing list, or audience segment is not found.

```jsonc
{
  "name": "Renamed announcement",
  "campaignGroupId": "ccg42l54f20i1la0lfooe3z12",
  "mailingListId": "cm06f5v0e45nf0ml5754o9cix",
  "audienceSegmentId": "cas42l54f20i1la0lfooe3z12",
  "scheduling": {
    "method": "schedule",
    "timestamp": "2026-06-22T14:00:00.000Z"
  }
}
```

Setting `audienceSegmentId` without `audienceFilter` clears any `audienceFilter` (and the reverse). When both are provided, the filter is applied on top of the segment — contacts must match both.

#### Email messages

##### Get an email message

```
GET /v1/email-messages/{emailMessageId}
```

Returns subject, preview text, sender fields, `ccEmail`, `bccEmail`, `languageCode`, `emailFormat` (`styled` or `plain`), `lmx`, `contentRevisionId`, `contactPropertiesFallbacks`, `eventPropertiesFallbacks`, `dataVariablesFallbacks`, and either `campaignId` or `transactionalId` (mutually exclusive). Returns `409` if the message uses legacy MJML format or content cannot be parsed.

##### Update an email message

```
POST /v1/email-messages/{emailMessageId}
```

Updates draft email-message fields. All body fields are optional in the schema, but you should send the fields you intend to change together with a valid `expectedRevisionId`.

```jsonc
{
  "expectedRevisionId": "crv52l54f20i1la0lfooe3z12",
  "subject": "Big spring updates",
  "previewText": "A quick look at what's new",
  "fromName": "Loops",
  "fromEmail": "hello",
  "replyToEmail": "support@example.com",
  "ccEmail": "team@example.com",
  "bccEmail": "archive@example.com",
  "languageCode": "en",
  "emailFormat": "styled",
  "lmx": "<Style themeId=\"cth42l54f20i1la0lfooe3z12\" />\n<Paragraph><Text>Hey there.</Text></Paragraph>\n<Component componentId=\"ccp42l54f20i1la0lfooe3z12\" />",
  "contactPropertiesFallbacks": {
    "firstName": "there"
  },
  "eventPropertiesFallbacks": {
    "planName": "Pro"
  },
  "dataVariablesFallbacks": {
    "resetLink": "https://example.com/reset"
  }
}
```

`fromEmail` is the sender username only, without `@` or a domain. The team's sending domain is appended automatically.

`ccEmail` and `bccEmail` require CC/BCC to be enabled for the team and are **not supported for campaign emails** (they are still accepted for workflow and transactional emails). `languageCode` requires translation to be enabled. A campaign that owns the message must be in `Draft` status; a transactional email must be a draft; a workflow must not be `Sending`.

Fallback maps (`contactPropertiesFallbacks`, `eventPropertiesFallbacks`, `dataVariablesFallbacks`) use per-key merge: a string value sets the fallback, `null` deletes it, and omitted keys are left unchanged.

LMX dynamic tags like `{contact.}`, `{event.}`, and `{data.}` can be inserted in all fields apart from `expectedRevisionId`. Which namespaces are valid depends on the parent email type: campaigns support `{contact.}`; workflow emails support `{contact.}` and `{event.}`; transactional emails support `{data.}`.

On success, the response includes a new `contentRevisionId` and may include non-fatal `warnings` from LMX compilation. LMX compile failures (invalid tags, missing required attributes such as `<Image src>`, `<Component componentId>`, `<Icon name>`, or `<Link href>`) return HTTP `422`. LMX payloads larger than **100 KB** return HTTP `413`.

##### Send a preview of an email message

```
POST /v1/email-messages/{emailMessageId}/preview
```

Send a test preview to one or more addresses. The accepted variable fields depend on the parent type:

- **Campaign** previews: `contactProperties`
- **Workflow** previews: `contactProperties` and `eventProperties`
- **Transactional** previews: `dataVariables`

Supplying a field the parent cannot reference returns `400`. Returns `429` when the daily preview limit (100 per team per rolling 24 hour window) is reached.

```jsonc
{
  "emails": ["you@example.com"],
  "contactProperties": {
    "firstName": "Alex"
  }
}
```

Returns `{ "id": "cem42l54f20i1la0lfooe3z12" }` on success.

##### Run Guardian checks on an email message

```
GET /v1/email-messages/{emailMessageId}/guardian
```

Runs the same Guardian validation as the Loops editor and returns `errors` (must be resolved before publish) and `warnings` (advisory). Checks depend on parent type: campaign (contact properties + links/buttons), workflow (contact + event properties + links/buttons), transactional (data variables + links/buttons). Returns `409` for MJML email messages.

#### Theme and component context for LMX

Use these endpoints when the LMX design guidance calls for Loops-native brand context:

1. `GET /v1/themes?perPage=20` to list available themes.
2. `GET /v1/themes/{themeId}` to inspect theme colors, fonts, body/background treatment, and button defaults.
3. Optionally `POST /v1/themes` or `POST /v1/themes/{themeId}` to create or update a theme (`styles` updates cascade; response includes `affectedEmailCount`).
4. `GET /v1/components?perPage=20` to list reusable components.
5. `GET /v1/components/{componentId}` to inspect component LMX bodies.
6. Optionally `POST /v1/components` or `POST /v1/components/{componentId}` to create or update a component (`lmx` updates cascade; response includes `affectedEmailCount`).
7. Reference selected assets with `<Style themeId="..." />` and `<Component componentId="..." />`.
8. Use `/v1/uploads` when the selected implementation needs a new image asset.
9. Update email-message content via `POST /v1/email-messages/{emailMessageId}` with the latest `expectedRevisionId`; save the returned `contentRevisionId` for the next update.

#### Themes

##### List themes

```
GET /v1/themes?perPage=20&cursor=...
```

Returns paginated themes (most recently created first). Use `themeId` in `<Style themeId="..." />`.

##### Get a theme

```
GET /v1/themes/{themeId}
```

Returns `id`, `name`, `isDefault`, timestamps, and `styles` (colors, fonts, padding, button styles, heading styles). Style keys match LMX `<Style>` tag attributes.

##### Create a theme

```
POST /v1/themes
```

```jsonc
{
  "name": "Dark mode",
  "styles": {
    "backgroundColor": "#111827",
    "bodyColor": "#1f2937",
    "textBaseColor": "#f9fafb",
    "buttonBodyColor": "#2563eb"
  }
}
```

`name` is required. `styles` is optional. Returns the created theme including `id` and `isDefault`.

##### Update a theme

```
POST /v1/themes/{themeId}
```

At least one of `name` or `styles` is required.

```jsonc
{
  "name": "Dark mode v2",
  "styles": {
    "buttonBodyColor": "#1d4ed8"
  }
}
```

When `styles` change, the update cascades to every email using this theme. `affectedEmailCount` reports how many emails were affected (`0` when only the name changed). Per-email manual style overrides are preserved: the cascade only changes properties an email has not overridden. An override is removed only when it becomes identical to the theme's new value.

#### Components

##### List components

```
GET /v1/components?perPage=20&cursor=...
```

Returns paginated reusable components. Use `componentId` in `<Component componentId="..." />`.

##### Get a component

```
GET /v1/components/{componentId}
```

Returns `id`, `name`, and the component body as LMX.

##### Create a component

```
POST /v1/components
```

```jsonc
{
  "name": "Header",
  "lmx": "<Section><H1><Text>Welcome to Acme</Text></H1></Section>"
}
```

`name` and `lmx` are required. Returns `id`, `name`, and `lmx`. Returns `422` for invalid LMX. Returns `413` if the LMX body exceeds the size limit.

##### Update a component

```
POST /v1/components/{componentId}
```

At least one of `name` or `lmx` is required.

```jsonc
{
  "name": "Header v2",
  "lmx": "<Section><H1><Text>Hello from Acme</Text></H1></Section>"
}
```

When the `lmx` body changes, the update cascades to every email using this component. `affectedEmailCount` reports how many were affected (`0` when only the name changed). A change that would introduce a dynamic variable an email using the component cannot use is rejected with `422`.

For LMX markup rules, use the separate `loops-lmx` skill.

#### Uploads

Use uploads to add image assets for LMX and email content.

Supported `contentType` values: `image/jpeg`, `image/png`, `image/gif`, and `image/webp`.

`contentLength` must be a positive integer no greater than **4,000,000 bytes** (4 MB). Returns `413` when the size limit is exceeded.

Upload rate limit: **50 uploads per 24 hours** per team. Returns `429` with `maxUploads` and `windowHours` when exceeded. Contact support to raise the limit.

##### Create an upload

```
POST /v1/uploads
```

```jsonc
{
  "contentType": "image/png",
  "contentLength": 102400
}
```

Returns `emailAssetId` and a `presignedUrl`. Upload the file with HTTP `PUT` to the returned `presignedUrl`, using the same `Content-Type` and `Content-Length` values.

Returns `400` for invalid request bodies or unsupported `contentType` (response may include `supportedContentTypes`).

##### Complete an upload

```
POST /v1/uploads/{emailAssetId}/complete
```

Use the returned `emailAssetId` as `{emailAssetId}` to finalize after the `PUT` upload succeeds. Success returns `emailAssetId` and `finalUrl`, which you can use in LMX `<Image src="..." />` attributes.

Returns `400` if the upload id is missing or the uploaded file has an unsupported content type. Returns `404` if the upload is not found.

### Webhooks

Loops POSTs events to your configured endpoint when contacts, email sends, and engagement change. Configure one URL in **Settings -> Webhooks**. Docs: https://loops.so/docs/webhooks

These are inbound events Loops sends to you. They are not HTTP API endpoints you call. Return any **2xx** status to acknowledge delivery. Delivery is capped at **10 events per second**; excess events are queued. History is retained for 30 days.

#### Verify signatures

Every request includes:

- `webhook-id` — unique delivery ID (use for idempotency)
- `webhook-timestamp` — Unix seconds
- `webhook-signature` — space-separated `v1,<base64>` signatures

Verify HMAC-SHA256 of `{webhook-id}.{webhook-timestamp}.{rawBody}` using the signing secret from the dashboard. Strip a leading `whsec_` prefix and base64-decode the remainder as the key. Reject timestamps outside a 5-minute tolerance. After a secret rotation, the previous secret remains valid for 24 hours and both signatures may appear in the header.

Read the raw request body as text before JSON-parsing. Do not verify against a re-serialized body.

Send `testing.testEvent` from the dashboard to confirm the endpoint and verification.

#### Shared payload fields

Every event includes `eventName`, `eventTime` (Unix seconds), and `webhookSchemaVersion` (`"1.0.0"`). Most events also include `contactIdentity` (`id`, `email`, `userId`).

Workflows were renamed from Loops on May 6, 2026. Webhook payloads still use `loop` names: `loop.email.sent`, `loopId`, `loopName`, and `sourceType: "loop"`.

| Object | Fields |
| --- | --- |
| `contactIdentity` | `id`, `email`, `userId` |
| `contact` | Same shape as find-contact, plus custom properties. Present on `contact.created`. |
| `email` | `id`, `emailMessageId`, `subject` |
| `mailingList` | `id`, `name`, `description`, `isPublic` |

`email.*` events include `sourceType` (`campaign`, `loop`, or `transactional`) plus the matching `campaignId`, `loopId`, or `transactionalId`.

#### Event types

| `eventName` | Notes |
| --- | --- |
| `contact.created` | New contact. Includes full `contact`. With double opt-in, fires only after confirmation; `optInStatus` is never `"pending"` or `"rejected"`. |
| `contact.unsubscribed` | Audience unsubscribe, or contact delete (alongside `contact.deleted`). Not a mailing-list unsubscribe. |
| `contact.deleted` | Contact deleted. |
| `contact.mailingList.subscribed` | Subscribed to a mailing list. With double opt-in, fires after confirmation. |
| `contact.mailingList.unsubscribed` | Unsubscribed from a mailing list. |
| `transactional.email.sent` | Transactional send. Includes `transactionalId`, `transactionalName`, `email`. |
| `campaign.email.sent` | Campaign send (one event per recipient). Includes `campaignId`, `campaignName`, `email`, optional `mailingLists`. |
| `loop.email.sent` | Workflow send (one event per recipient). Includes `loopId`, `loopName`, `email`, optional `mailingLists`. |
| `email.delivered` | Delivered. |
| `email.softBounced` | Temporary delivery failure; may still deliver after retries. |
| `email.hardBounced` | Permanent failure; also sends `contact.unsubscribed`. |
| `email.opened` | Opened. Campaign and workflow only (not transactional). |
| `email.clicked` | Link clicked. Campaign and workflow only. |
| `email.unsubscribed` | Unsubscribe link. Also sends `contact.unsubscribed` or `contact.mailingList.unsubscribed`. Campaign and workflow only. |
| `email.resubscribed` | Resubscribed from the preference center. Campaign and workflow only. |
| `email.spamReported` | Marked as spam. |
| `testing.testEvent` | Dashboard test. Payload is `{ eventName, eventTime, message: "test", webhookSchemaVersion }`. |

```json
{
  "eventName": "contact.created",
  "eventTime": 1734425918,
  "webhookSchemaVersion": "1.0.0",
  "contactIdentity": {
    "id": "cm4itta800003ow9hhekzk94o",
    "email": "user@example.com",
    "userId": null
  },
  "contact": {
    "id": "cm4itta800003ow9hhekzk94o",
    "email": "user@example.com",
    "firstName": "Alex",
    "lastName": "Chen",
    "source": "API",
    "subscribed": true,
    "userGroup": "premium",
    "userId": null,
    "mailingLists": { "cm06f5v0e45nf0ml5754o9cix": true },
    "optInStatus": "accepted"
  }
}
```

```json
{
  "eventName": "email.opened",
  "eventTime": 1734425918,
  "webhookSchemaVersion": "1.0.0",
  "sourceType": "campaign",
  "campaignId": "ccm42l54f20i1la0lfooe3z12",
  "email": {
    "id": "cem42l54f20i1la0lfooe3z12",
    "emailMessageId": "cem52l54f20i1la0lfooe3z12",
    "subject": "Big spring updates"
  },
  "contactIdentity": {
    "id": "cm4ittmhq0011ow9h6fb460yw",
    "email": "user@example.com",
    "userId": null
  }
}
```

---

## Code Examples

### JavaScript SDK

```typescript
import { LoopsClient } from "loops";

const loops = new LoopsClient(process.env.LOOPS_API_KEY!);

await loops.sendEvent({
  email: "user@example.com",
  eventName: "paidSubscription",
  eventProperties: { planName: "pro" },
});

await loops.createContact({
  email: "user@example.com",
  properties: {
    firstName: "Alex",
    userGroup: "premium",
  },
  mailingLists: { cm06f5v0e45nf0ml5754o9cix: true },
});

await loops.sendTransactionalEmail({
  transactionalId: "cll42l54f20i1la0lfooe3z12",
  email: "user@example.com",
  dataVariables: { resetLink: "https://yourapp.com/reset?token=abc" },
});
```

### Creating and editing a campaign

```javascript
const headers = {
  Authorization: `Bearer ${process.env.LOOPS_API_KEY}`,
  "Content-Type": "application/json",
};

const created = await fetch("https://app.loops.so/api/v1/campaigns", {
  method: "POST",
  headers,
  body: JSON.stringify({ name: "Spring product announcement" }),
}).then((r) => r.json());

const [themes, components] = await Promise.all([
  fetch("https://app.loops.so/api/v1/themes?perPage=20", { headers }).then((r) =>
    r.json()
  ),
  fetch("https://app.loops.so/api/v1/components?perPage=20", { headers }).then(
    (r) => r.json()
  ),
]);

// Inspect candidate themes/components before writing LMX or uploading assets.
// Choose explicit IDs from the inspected team-owned assets; do not infer them
// from list order or component names.

// Flow: create upload -> PUT to presignedUrl -> complete upload.
const imageBytes = /* Uint8Array|ArrayBuffer|Buffer */;
const contentType = "image/png";
const contentLength = imageBytes.byteLength ?? imageBytes.length;

const createdUpload = await fetch("https://app.loops.so/api/v1/uploads", {
  method: "POST",
  headers,
  body: JSON.stringify({ contentType, contentLength }),
}).then((r) => r.json());

// Upload the file to the pre-signed URL using HTTP PUT.
// Important: use the same Content-Type and Content-Length from the create call.
await fetch(createdUpload.presignedUrl, {
  method: "PUT",
  headers: {
    "Content-Type": contentType,
    "Content-Length": String(contentLength),
  },
  body: imageBytes,
});

// Finalize the asset and get the public URL.
const completedUpload = await fetch(
  `https://app.loops.so/api/v1/uploads/${createdUpload.emailAssetId}/complete`,
  { method: "POST", headers }
).then((r) => r.json());

const imageUrl = completedUpload.finalUrl;

const lmx = `
<Paragraph><Text>Hey there, here is what's new.</Text></Paragraph>
<Image src="${imageUrl}" alt="New product showcase" />`;

const updated = await fetch(
  `https://app.loops.so/api/v1/email-messages/${created.emailMessageId}`,
  {
    method: "POST",
    headers,
    body: JSON.stringify({
      expectedRevisionId: created.emailMessageContentRevisionId,
      subject: "Big spring updates",
      previewText: "A quick look at what's new",
      fromName: "Loops",
      fromEmail: "hello",
      replyToEmail: "support@example.com",
      lmx,
    }),
  }
).then((r) => r.json());

// Save updated.contentRevisionId for the next update.
```

### Creating and publishing a transactional email

```javascript
const headers = {
  Authorization: `Bearer ${process.env.LOOPS_API_KEY}`,
  "Content-Type": "application/json",
};

const created = await fetch("https://app.loops.so/api/v1/transactional-emails", {
  method: "POST",
  headers,
  body: JSON.stringify({ name: "Password reset" }),
}).then((r) => r.json());

await fetch(
  `https://app.loops.so/api/v1/email-messages/${created.draftEmailMessageId}`,
  {
    method: "POST",
    headers,
    body: JSON.stringify({
      expectedRevisionId: created.draftEmailMessageContentRevisionId,
      subject: "Reset your password",
      fromName: "Loops",
      fromEmail: "hello",
      lmx: '<Style themeId="cth42l54f20i1la0lfooe3z12" />\n<Paragraph><Text>Click {data.resetLink} to reset.</Text></Paragraph>',
    }),
  }
);

const published = await fetch(
  `https://app.loops.so/api/v1/transactional-emails/${created.id}/publish`,
  { method: "POST", headers }
).then((r) => r.json());

// Send using the transactional email id.
await fetch("https://app.loops.so/api/v1/transactional", {
  method: "POST",
  headers,
  body: JSON.stringify({
    email: "user@example.com",
    transactionalId: published.id,
    dataVariables: { resetLink: "https://yourapp.com/reset?token=abc" },
  }),
});
```

### Next.js App Router event send

```typescript
// app/api/register/route.ts
import { LoopsClient } from "loops";
import { NextResponse } from "next/server";

const loops = new LoopsClient(process.env.LOOPS_API_KEY!);

export async function POST(req: Request) {
  const { email, plan } = await req.json();

  await loops.sendEvent({
    email,
    eventName: "signup",
    eventProperties: { plan },
  });

  return NextResponse.json({ success: true });
}
```

All Loops API calls must be server-side.

### Stripe webhook example

```typescript
// app/api/webhooks/stripe/route.ts
import Stripe from "stripe";
import { LoopsClient } from "loops";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);
const loops = new LoopsClient(process.env.LOOPS_API_KEY!);

export async function POST(req: Request) {
  const sig = req.headers.get("stripe-signature")!;
  const body = await req.text();
  const event = stripe.webhooks.constructEvent(
    body,
    sig,
    process.env.STRIPE_WEBHOOK_SECRET!
  );

  if (event.type === "checkout.session.completed") {
    const session = event.data.object;
    const customerEmail = session.customer_details?.email;
    const planName = session.metadata?.planName;

    if (customerEmail) {
      await loops.sendEvent({
        email: customerEmail,
        eventName: "paidSubscription",
        eventProperties: { planName },
      });
    }
  }

  return new Response("ok");
}
```

This example uses the Next.js App Router. If you are using the Pages Router, use the corresponding `pages/api` handler shape and disable body parsing so Stripe signature verification still works.

### Receive a Loops webhook

```typescript
// app/api/webhooks/loops/route.ts
import crypto from "node:crypto";
import { NextResponse } from "next/server";

const SECRET_PREFIX = "whsec_";
const TOLERANCE_SECONDS = 300;

function verifyLoopsWebhook(headers: Headers, rawBody: string, secret: string) {
  const id = headers.get("webhook-id");
  const timestamp = headers.get("webhook-timestamp");
  const signatureHeader = headers.get("webhook-signature");
  if (!id || !timestamp || !signatureHeader) {
    throw new Error("missing webhook headers");
  }

  const ts = Number(timestamp);
  const now = Math.floor(Date.now() / 1000);
  if (!Number.isFinite(ts) || Math.abs(now - ts) > TOLERANCE_SECONDS) {
    throw new Error("invalid webhook timestamp");
  }

  const encoded = secret.startsWith(SECRET_PREFIX)
    ? secret.slice(SECRET_PREFIX.length)
    : secret;
  const expected = crypto
    .createHmac("sha256", Buffer.from(encoded, "base64"))
    .update(`${id}.${timestamp}.${rawBody}`)
    .digest("base64");

  const matched = signatureHeader.split(/\s+/).some((entry) => {
    const comma = entry.indexOf(",");
    if (comma === -1) return false;
    if (entry.slice(0, comma) !== "v1") return false;
    const actual = Buffer.from(entry.slice(comma + 1));
    const expectedBuf = Buffer.from(expected);
    return (
      actual.length === expectedBuf.length &&
      crypto.timingSafeEqual(actual, expectedBuf)
    );
  });
  if (!matched) throw new Error("invalid webhook signature");
}

export async function POST(req: Request) {
  const rawBody = await req.text();
  verifyLoopsWebhook(
    req.headers,
    rawBody,
    process.env.LOOPS_SIGNING_SECRET!
  );

  const event = JSON.parse(rawBody);
  // Handle event.eventName. Use webhook-id for idempotency.
  return NextResponse.json({ ok: true, eventName: event.eventName });
}
```

Return any 2xx status to acknowledge delivery. Read `rawBody` before parsing JSON.

### Python

```python
import os
import requests

LOOPS_API_KEY = os.environ["LOOPS_API_KEY"]
BASE_URL = "https://app.loops.so/api"
headers = {
    "Authorization": f"Bearer {LOOPS_API_KEY}",
    "Content-Type": "application/json",
}

resp = requests.post(
    f"{BASE_URL}/v1/transactional",
    headers=headers,
    json={
        "email": "user@example.com",
        "transactionalId": "cll42l54f20i1la0lfooe3z12",
        "dataVariables": {
            "resetLink": "https://yourapp.com/reset?token=abc123"
        },
    },
)
resp.raise_for_status()
```

### curl

```bash
curl -X POST https://app.loops.so/api/v1/events/send \
  -H "Authorization: Bearer $LOOPS_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","eventName":"signup","eventProperties":{"plan":"pro"}}'

curl -X POST https://app.loops.so/api/v1/contacts/create \
  -H "Authorization: Bearer $LOOPS_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","firstName":"Alex","subscribed":true,"mailingLists":{"cm06f5v0e45nf0ml5754o9cix":true}}'
```

---

## Common Errors

| Status | Meaning | Fix |
| --- | --- | --- |
| 401 | Invalid API key, or workflow/content API not enabled | Check the key is correct and has not been revoked; confirm the workflow or content API is enabled for your team |
| 400 | Bad request | Check required fields and value types |
| 404 | Not found | Contact, transactional email, campaign, campaign group, transactional group, workflow group, audience segment, workflow, workflow node, event pattern, theme, component, email message, or upload ID does not exist |
| 409 | Conflict | Email or userId already exists, idempotency key was reused, campaign is not draft, transactional email has no draft to publish, email message uses MJML or content cannot be parsed, email/workflow `expectedRevisionId` is stale, a reserved group name was used, or workflow delete needs `confirmDelete: true` because the workflow is sending or has queued contacts |
| 413 | Payload too large | LMX body exceeds 100 KB (email messages) or the component LMX size limit, or upload `contentLength` exceeds 4 MB |
| 422 | LMX failed to compile, draft failed validation / unsafe content, or a component body change would break emails using it | Fix invalid LMX, missing required LMX attributes, XML escaping, Guardian/publish validation issues, or incompatible component variables |
| 429 | Rate limited, daily preview limit reached, or upload limit exceeded | Back off and retry |
| 501 | Not implemented | Requested workflow node update is not supported |
| CORS error | Client-side request | Move the API call to your server |

Most v1 contact, event, and transactional request body string values are limited to **500 characters**. LMX content on email-message updates follows the LMX payload limit.

---

## Tips

- **Upsert pattern**: Use `PUT /v1/contacts/update` when you are not sure if a contact exists.
- **`addToAudience` on transactional**: Setting this to `true` when sending a transactional email will make sure the recipient is added to the audience for marketing emails.
- **Finding your `transactionalId`**: Go to the Loops dashboard -> Transactional, or call `GET /v1/transactional-emails`.
- **Transactional email lifecycle**: Create with `POST /v1/transactional-emails`, edit the draft via `/v1/email-messages/{draftEmailMessageId}`, publish with `POST /v1/transactional-emails/{id}/publish`, then send with `POST /v1/transactional`.
- **Upload limits**: Max file size is 4 MB. Max 50 uploads per 24 hours per team.
- **`fromEmail` on email messages**: Pass only the sender username, such as `"updates"`, not `"updates@example.com"`.
- **Content revision IDs**: After `POST /v1/campaigns`, use `emailMessageContentRevisionId` as the first `expectedRevisionId`. After each `POST /v1/email-messages/{id}`, save `contentRevisionId` for the next update.
- **Themes and components before LMX**: List and get themes/components so `<Style themeId="..." />` and `<Component componentId="..." />` reference real IDs. Create or update with `POST /v1/themes` and `POST /v1/components`. Style and LMX body updates cascade to emails using that asset; responses include `affectedEmailCount`.
- **Draft-only writes**: Campaign and email-message updates return `409` once a campaign leaves draft status.
- **Campaign audience**: Target a `mailingListId`, `audienceSegmentId`, and/or inline `audienceFilter`. Setting a segment without a filter (or a filter without a segment) clears the other; pass both to apply the filter on top of the segment.
- **Campaign scheduling**: Use `scheduling.method` of `"now"` or `"schedule"`. `timestamp` is required and must be in the future when scheduling.
- **Groups**: Campaign, transactional, and workflow groups cannot be named `"Unsorted"`, and the Unsorted group cannot be edited. Omit `campaignGroupId` or `workflowGroupId` on create to use the team's Unsorted group.
- **Resource URLs**: Campaign, transactional, and workflow responses include a `url` field pointing at the object in the Loops app.
- **Metrics**: `GET /v1/campaigns/{id}/metrics` and `GET /v1/workflows/{id}/nodes/{nodeId}/metrics` return engagement counters (campaigns must already have been sent; workflow metrics are `SendEmailAction` only). `GET /v1/transactional-emails/{id}/metrics` returns delivery counters totalled across published versions.
- **Workflow mutations**: Create with `POST /v1/workflows` (optional `workflowGroupId`), inspect with `GET /v1/workflows/{id}`, mutate nodes via `/v1/workflows/{id}/nodes`, and always pass the latest `workflowRevisionId` as `expectedRevisionId`. Move groups with `workflowGroupId` on update. Use `/mailing-list` for list changes. Destructive ops support `dryRun` and `queuedContactPolicy: "discard"`. Insert with `between`, `before`, or `after`. Reroute a single-output connection with `/nodes/{nodeId}/reroute`. Public workflows are capped at 400 nodes.
- **Workflow delete**: `DELETE /v1/workflows/{id}` returns `204`. If the workflow is sending or has queued contacts, retry with `confirmDelete: true`.
- **Event patterns for triggers**: List with `GET /v1/event-patterns`, then set `eventPatternId` or `eventName` on an `EventTrigger` node update.
- **Inbound Loops webhooks**: Configure one endpoint in Settings → Webhooks. Verify `webhook-id` / `webhook-timestamp` / `webhook-signature` against the raw body. Return 2xx. Workflow events keep `loop` names (`loop.email.sent`, `sourceType: "loop"`).
- **Email message previews**: Use `POST /v1/email-messages/{emailMessageId}/preview`. Variable fields depend on whether the parent is a campaign, workflow, or transactional email.
- **Guardian checks**: Use `GET /v1/email-messages/{emailMessageId}/guardian` before publish to surface blocking errors and advisory warnings.
- **Email message fallbacks**: `contactPropertiesFallbacks`, `eventPropertiesFallbacks`, and `dataVariablesFallbacks` merge per key (string sets, `null` deletes, omitted keys unchanged).
- **Mailing list membership**: Pass `{ "cm06f5v0e45nf0ml5754o9cix": true }` to subscribe and `{ "cm06f5v0e45nf0ml5754o9cix": false }` to unsubscribe.
- **Event name matching**: The `eventName` must match the configured Loops trigger exactly.
- **Idempotency keys**: Use these any time an operation could be retried, such as webhook handlers or confirmation flows.
