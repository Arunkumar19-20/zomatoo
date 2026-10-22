# Concurrency and correctness report

What was run, against what, and what came out. Everything below is reproducible from the repository.

**Environment:** PostgreSQL 16 in Docker (Testcontainers), Spring Boot 4.0.5 on Java 26, one laptop. The H2 suite runs the same service code; the Postgres suites are the ones that prove the database-level claims.

## The invariant

For every drop: `reservedSlots == count(HELD) + count(CONFIRMED)` and `0 <= reservedSlots <= totalSlots`. A customer holds at most one `HELD`/`CONFIRMED` reservation and has at most one `WAITING`/`OFFERED` waitlist entry per drop. Every test below that mutates a drop re-checks all three in SQL afterwards.

## Results (real PostgreSQL)

| Scenario (`DropWaitlistPostgresRaceTest`) | Result |
| :--- | :--- |
| **500 customers, 20 slots**, all reserving at once | exactly 20 `HELD`, 480 `SOLD_OUT`, 0 other outcomes; `reservedSlots = 20`; wall time 1.7 to 4.0 s across runs |
| **Same customer, 24 simultaneous reserves through two app instances** (separate JVM locks, so only the database arbitrates) | exactly 1 hold created; the losing transactions roll back their slot increment; `reservedSlots = 1` |
| **Same customer, 24 simultaneous waitlist joins through two instances** | every call resolves to one entry; 1 `WAITING` row; the partial unique index exists |
| **5 holders release at the same instant, 25 people waiting** | the 5 oldest waiters (and only they) hold the 5 slots; an outsider's reserve gets `SOLD_OUT` the whole time |
| **Chaos: 60 customers, 6 slots, 12 rounds** of concurrent releases, forced expiries and sweeps | invariant holds after every round; while anyone is waiting, no slot sits idle |
| Deleting a drop whose reservations are all settled, with real foreign keys | succeeds; a drop with live holds is refused with `DROP_HAS_RESERVATIONS` |

Also on Postgres (`DropPostgresIntegrationTest`, pre-existing): a 50-user reserve race, webhook idempotency under concurrent deliveries, and the late-payment reclaim path.

## Payment-aware hold and refunds (`DropHoldPolicyAndWaitlistTest`, H2)

- Reserve holds 10 min; checkout tops the hold up to at least 5 min and never shortens it; creating the PaymentIntent or a Stripe `processing` webhook extends it by 5 min; nothing passes `createdAt + 20 min`.
- A hold that lapsed a moment before the `processing` webhook is rescued, and the sweeper leaves it alone.
- An expired hold cancels its unpaid order; the abandoned-order job never cuts a live hold short.
- A payment arriving after the hold lapsed: slot free means the slot is reclaimed and the cancelled order is revived; slot taken (or a newer reservation held) means the order is cancelled at once and the refund is retried with back-off until Stripe accepts it.
- Waitlist: FIFO hand-off without the counter ever dipping, cascading offers, claim on checkout, leaving while offered, bounded queue, capacity raises, drops that end. A committed in-app notification is created for each offer (the test fails without the `REQUIRES_NEW` fix that this run found).

## Live end-to-end (real HTTP, real Postgres, `scripts/demo/e2e_drops_smoke.py`)

25 checks over the running backend in the `demo` profile: login, reserve (201 then idempotent 200), sold out (409 `SOLD_OUT`), waitlist positions, release then hand-off with `remainingSlots` staying 0, no sniping, offer notification row, checkout priced from the drop, PaymentIntent, signed webhook then `PAID` and `CONFIRMED`, declined offer passes to the next waiter, the SQL invariant, sweeper expiry cancelling the unpaid order, the late payment on a taken slot ending `CANCELLED`/`REFUNDED`. The JSON it captures is committed in `test/fixtures` and parsed by the Flutter DTOs in `test/api_contract_test.dart`, so client and server cannot drift apart silently.

The Flutter web app was also driven by hand against that backend: login, Limited Drops row, reserve, live countdown, pay, My Orders; hold expiry screen; join waitlist, another customer releases, the offer banner and snackbar appear within one poll.

## Defects this work found and fixed

- A reserve race across app instances would have failed on Postgres (an aborted transaction was reused for the compensation); it now rolls back as a whole and resolves to the winner.
- Late payment with a newer reservation would have thrown inside the webhook and made Stripe retry forever; it is now a refund case.
- Editing a drop could overwrite `reservedSlots` with a stale value (`@DynamicUpdate` now prevents it); capacity cannot be cut below what is reserved.
- The waitlist-offer notification was silently never saved (listener ran after the transaction had committed).
- `GET /orders/customer/{id}`, which My Orders called, does not exist on the backend; the screen now uses `GET /orders`.
- Without a Stripe key the app crashed with `StripeConfigException` instead of simulating the sheet.
- A paid-but-cancelled order (slot lost) was shown to the customer as a successful payment.
- Deleting a drop that had reservations returned 500; it now deletes settled history and refuses live holds.
- Flyway never ran (Spring Boot 4 needs its own Flyway starter), so the partial unique index depended on a dev seeding hook; `DropSchemaInitializer` now creates it on every start.

## Not covered

Stripe's live test mode (the fake gateway plus signed webhooks stand in), push delivery of waitlist offers (the client polls every 4 s), and more than one real server process in front of the same database (two `DropService` instances in one JVM stand in).
