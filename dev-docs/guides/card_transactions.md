# What happens when I swipe / tap / dip my HCB card?

Our cards are issued by Stripe so the process starts with them. They have a socket connection with Visa’s card network which receives a message when you attempt to buy something with your card, they do their preliminary checks (including the $40k daily maximum on each card configured in Stripe) and, if the authorisation passes, then pass information about the authorisation to us via a webhook. At this point, it’s up to us to approve or reject the “authorisation”. An authorisation is different from a transaction:

> Card authorisation is the process in which the financial institution that issued a credit or debit card that’s been submitted for payment verifies that the card can be used for a given transaction.

Authorisations aren’t guaranteed to become transactions but they often do. When Stripe sends us this webhook it has handled by `StripeController#handle_issuing_authorization_request` which calls `StripeAuthorizationService::Webhook::HandleIssuingAuthorizationRequest`. That service checks that the card has the balance available for the authorisation (based on the card’s event / subledger balance, the cardholder’s spending controls) and that this type of purchase is allowed (card grants have category / merchant locks and all cards have a cash withdrawal lock). 

We then respond to the webhook with an approved / not approved message. We are required to respond within two seconds otherwise the authorisation will be declined.

No matter whether we approve or decline the transaction, Stripe will send us another webhook which will be handled by `StripeController#handle_issuing_authorization_created` . `StripeAuthorizationService::CreateFromWebhook` is called, this service does the following:

* Creates a `RawPendingStripeTransaction`
* Creates a `CanonicalPendingTransaction`
* Map that `CanonicalPendingTransaction` to the event based on the Stripe Card’s event
* If we declined the webhook, it will then:
  * Decline the `CanonicalPendingTransaction`
  * Send a text message / email to the card owner
* If we approved the webhook, it will email and text the card owner to let them know.
  * We’ll also email the admin notification email if it was a cash withdrawal.

At the same time, Stripe deducts the authorisation’s amount from our Issuing balance and holds it until the authorisation is either captured, voided, or expired without capture (we’ll go through these soon!).

`StripeController#handle_issuing_authorization_updated` is the method that handles any updates from Stripe about our issuing authorisation. 

An example of where this is used is when a merchant performs a partial reversal and reduces the amount of the authorisation. 

If the authorisation is voided (the merchant chooses not to charge the customer in the end. For example, they issue a refund before capturing), the issuing authorisation will be updated to have an `amount` of 0 and a `status` of `reversed`. The `CanonicalPendingTransaction` will have its amount updated to reflect this.

If the authorisation expires (the merchant doesn’t explicitly void it but they run out of time to capture the authorised amount), Stripe will set the `status` to `reversed`. The amount will not always be zero, however, it “represents any remaining amount authorised for possible late captures”.

Eventually the authorisation will continue being updated until the `amount` is 0.

Alright, so what does it mean for the merchant to “capture” an authorisation? Essentially it’s when a merchant confirms they intend to charge this customer and provide a final amount. When the authorisation is captured, Stripe creates a “transaction” and sets the status of the authorisation to closed. I wrote about how we import Stripe transactions in “How a transaction gets mapped to an event and a HCB code on HCB.” That guide describes how the `CanonicalPendingTransaction` I described above becomes a `CanonicalTransaction`.

Capturing has a couple of edge cases:

* Partial capture: merchants only capture part of the authorisation’s amount. In this case the `CanonicalTransaction` will have a lower amount than the `CanonicalPendingTransaction`. Stripe may continue to hold onto that additional amount, in case of multi capture.

* Over capture: merchants capture more than the authorisation’s amount. The most common example of this is a tip at a restaurant. In this case the `CanonicalTransaction` will have a higher amount than the `CanonicalPendingTransaction`. We can’t reject an over capture so this can cause organisations to go negative. If we don’t agree with an over capture, we need to dispute it.

* Multi capture: merchants can capture from an authorised amount multiple times. This will lead to multiple `CanonicalTransaction`s which will all be mapped to the same HCB code (Stripe card transactions are bundled into HCB codes based on their authorisation).

* Force capture: merchants can essentially brute force through a declined authorisation by performing a “force capture”. They can also use this to capture money without an authorisation. We’ll create a `CanonicalTransaction` and map it to an event as usual. And, if this was fraudulent, it’s on us to dispute it. This is the cause of negative organisations. We aren’t able to block them. An example of a legitimate forced capture is a food purchase on an aircraft without internet. These terminals aren’t connected to the internet and can’t do a real-time authorisation. 

For more information, I recommend reading:

* https://docs.stripe.com/issuing/purchases/authorizations
* https://docs.stripe.com/issuing/purchases/transactions
* https://docs.stripe.com/issuing/controls/real-time-authorizations
* https://stripe.com/resources/more/card-authorization-explained

\- [@sampoder](https://github.com/sampoder)

