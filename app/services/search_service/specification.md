# **Command Bar Search Specification**

Searches are made up of one or more queries.

The most basic case for a search is that it has one query. In this case, the results delivered by this query are the results of the search.

In cases where there are multiple queries, each preceding query narrows down the result of the next query. So for example, if you query a user and then query a transaction, the transaction query will only return transactions associated with the first result of the user query.

Every query except for the first query must have a defined return type. This is because the type modifier is used to break up queries, eg “@user Sam Poder @txn Outernet” gets split up into “@user Sam Poder” and “@txn Outernet”. 

Types are indicated by “@[type_name]”. Filters are given by “[property_name operator value]”. We support these operators: “>”, “<”, “>=”, “<=”, and “=”.

We also support subtypes for types such as Transaction which can be broken up into Card Charges, Invoices, Donations etc. These are indicated by “@[type_name]:[subtype_name]”

When there is no defined type for a query, we will return results for all the possible types (possible types are determined based on the filters provided and the response type of the following query, which must be a valid child of this query).

The return types available are as follows:

* Transactions
  * Filters: amount, date
  * Children: none
  * Subtypes: ACH Transfer, Mailed Check, Account Transfer, Card Charge, Check Deposit, Donation, Invoice, Refund, Fiscal Sponsorship Fee
* Organisations
  * Filters: date
  * Children: Transactions, Stripe Cards, Users
  * Subtypes: none
* Stripe Cards
  * Filters: date
  * Children: Transactions
  * Subtypes: none
* Users
  * Children: Transactions, Stripe Cards, Organisations
  * Subtypes: none

**Example Searches**

Whilst not explicitly stated, all results will be items that the current users can access.

```
Outernet
```

This will search for all Stripe Cards, Users, Transactions, and Events similar to “Outernet”. For example, you’ll get “Outernet” events and transactions which have “Outernet” in their memo.

```
@org Outernet
```

This will search for all organisations with Outernet in their name.

```
Outernet @txn Stickers
```

```
@org Outernet @txn Stickers
```

These two searches will both return transactions related to stickers on the Outernet organisation. 

```
@org [date > 21/03/2005] Outernet
```

```
@org Outernet [date > 21/03/2005]
```

Both of these searches will return organisations with “Outernet” in their name created after March 21st, 2005. Date parsing uses ~[Chronic’ spec](https://github.com/mojombo/chronic)~.

```
@org [date > 21/03/2005] Outernet @txn [amount > $5] Stickers
```

This search will return transactions related to stickers over $5 on the organisation whose name is most similar to “Outernet” out of all the organisations created after March 21st, 2005. 

```
@user Sam Poder @org Robotics @txn FIRST 
```

This search will return all transactions with “FIRST” in the memo made by Sam Poder on organisations of his with “Robotics” in the name.

```
@user Sam Poder @org Hack Club HQ @card 1234 @txn Stickers
```

```
@org Hack Club HQ @user Sam Poder @card 1234 @txn Stickers
```

These searches both return sticker-related transactions made by Sam Poder on the Hack Club HQ organisation using his card with the last four “1234”. However, there is one difference. In the first search, the organisation “Hack Club HQ” is pulled from the  organisations Sam Poder is a part of. Meanwhile, in the second search, the user “Sam Poder” is pulled from the list of users that are apart of the “Hack Club HQ” organisation.
