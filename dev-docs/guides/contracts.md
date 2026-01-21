# Contracts

A core part of HCB's onboarding process is the fiscal sponsorship contract. The `Contract` model is used for all contracts, and contains information about each contract such as its state and external service (usually DocuSeal).

`Contract` implements single-table inheritance to support other types of contracts, such as termination contracts. Currently, only `Contract::FiscalSponsorship` is implemented and overrides `payload` (what HCB sends to DocuSeal to create the contract) and `required_roles` (the party roles that must exist on the contract before sending).

`Contract` also has a couple important associations:

- `contractable` - polymorphic association to the source of the contract, which is expected to implement the `Contractable` concern. Currently, only `OrganizerPositionInvite` does this.
- `parties` - each signing party has a `Contract::Party` method linked to its `Contract`. Each party stores its own signing state and a role, which can be `signee`, `cosigner`, or `hcb`.

Callbacks on `Contract::Party` and `Contract` ensure that data is always kept in sync and allows the `Contractable` to perform additional tasks when its contract's status changes.

## Creating contracts

Currently, all contracts are created from an `OrganizerPositionInvite`. When an admin invites someone to an organization (such as when activating the organization), they have the option to invite them as a contract signee. If they are under 18 years old, they will have to provide a cosigner email (a parent or guardian).

This calls `OrganizerPositionInvite#send_contract`, which handles the logic of creating the relevant `Contract` and `Contract::Party` models. It then calls `Contract#send!` to finalize the contract and send it to DocuSeal.

Contracts should never be created outside of their `Contractable`'s model to ensure that they are always created with the correct information before sending.

### Creating custom plans

When a custom contract template will be used for a large number of organizations, you should create a new `Event::Plan` subclass for those organizations. In that subclass, make sure to include:

```ruby
  def contract_docuseal_template_id
    # Paste in DocuSeal's template ID here - you can copy this number from the URL of the template page on DocuSeal
  end
```

Any contracts created for organizations with that plan will automatically use that template. Make sure the template uses the same fields as the main fiscal sponsorship contract template.

### Sending manual contracts

Most contracts are sent automatically by HCB, but we sometimes need custom contracts for a specific organization. You'll need console access to do this.

1. **Send and sign the contracts**. This can be done via any platform, such as DocuSeal or SignNow.
2. **Upload the PDF to HCB**. Go to the organization's documents tab and upload the PDF of the signed contract.
3. **Create the contract in HCB**. You might get a prompt from PaperTrail when running this in the console - use the email of the organization's HCB point of contact. If multiple signees sign the same contract, run it once for each signee, using the same document.

```ruby
# Copy the event ID from HCB
EVENT_ID=

# Use the last part of the URL to the document on HCB
DOCUMENT_SLUG=

# The email of the invited user who signed the contract
INVITEE_EMAIL=

event = Event.find(EVENT_ID)
document = Document.find_by!(slug: DOCUMENT_SLUG)
invite = event.organizer_position_invites.find_by!(email: INVITEE_EMAIL)
invite.update!(is_signee: true)

# external_service 999 identifies a manually-sent contract
contract = Contract::FiscalSponsorship.create!(contractable: invite, include_videos: false, external_service: 999, document:)

contract.parties.create!(user: invite.user, role: :signee)

# If the contract had a cosigner, uncomment and add their email here here
# contract.parties.create!(external_email: "", role: :cosigner)

contract.mark_signed!
```

## DocuSeal

DocuSeal is the document signing service HCB uses for sending contracts. On `Contract`, `external_id` refers to the DocuSeal submission ID, and `external_template_id` refers to the DocuSeal template ID that was used to create the contract.

`DocusealController` handles webhooks from DocuSeal. We only need two event types: `form.completed` (sent when someone signs a contract) and `form.declined` (sent when someone declines to sign a contract). If HCB has a corresponding `Contract` when it gets either of these webhooks, it'll update it or the associated party accordingly.
