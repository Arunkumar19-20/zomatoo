# Cravey: project guide

How to read this: sections 1 to 3 need no code. Sections 4 to 7 connect the product flow to the code. Section 10 is a self-test.

---

## 1. What the project does (no code)

Cravey is a food-delivery app with one special feature: **limited drops**. A restaurant announces a small batch of a dish (say 20 plates) that go on sale at a set time. Hundreds of people want them at once.

The hard problem: **many customers compete for few plates while payments are still processing.** If you only decrement stock when a payment succeeds, 200 people can pay for 20 plates. If you take stock the moment someone taps, abandoned carts lock plates up forever.

Cravey's answer:

1. Tapping **Reserve** takes one plate out of the pool for **10 minutes** (a *hold*) with a visible countdown.
2. The customer pays within the hold. Paying turns the hold into a confirmed plate.
3. If they don't pay in time, the plate is released automatically.
4. If a drop is sold out, people join a **waitlist**. The moment a plate is released it goes straight to the first person in line, so nobody can sneak in between.
5. If someone pays after their hold ran out and the plate is gone, they are refunded automatically (and the refund is retried until it works).

Around that sits an ordinary delivery platform with four roles: **Customer** (browse, cart, order, pay, track), **Restaurant Owner** (kitchen queue, menu), **Delivery Partner** (accept, deliver), **Admin** (users, restaurants, analytics).

---

## 2. The stack and what each piece buys you

| Layer | Technology | Why it matters in this project |
| :--- | :--- | :--- |
| Mobile/web client | **Flutter + Dart** | One codebase for Android, iOS, web, desktop. The demo ran in a browser from the same code as the phone app. |
| Client state | **provider** (`ChangeNotifier`) | `DropState` holds drops/holds/waitlist; every widget that depends on it rebuilds when it changes. Simple, testable without a device. |
| Client HTTP | **dio** + `AuthInterceptor` | Adds the JWT to requests and, on a 401, refreshes the token once for all in-flight requests (single-flight). |
| Client secrets | **flutter_secure_storage** | Stores tokens encrypted on device. |
| Payments (client) | **flutter_stripe** | Stripe's payment sheet; card data never touches your server. |
| Maps | **flutter_map** (OpenStreetMap) | Order tracking without a paid map vendor. |
| API server | **Spring Boot 4 / Java 26 / Spring MVC** | REST controllers, dependency injection, scheduling (`@Scheduled`) for the sweepers. |
| Persistence | **Spring Data JPA + Hibernate** | Entities become tables; **custom `@Query` UPDATEs** do the atomic stock math. |
| Database | **PostgreSQL** | Row locks and partial unique indexes make "never oversell" a database guarantee, not just application logic. |
| Security | **Spring Security + JWT (jjwt)** + Google OAuth | Stateless auth: 15 min access token + refresh token; roles `CUSTOMER`, `OWNER`, `DELIVERY_PARTNER`, `ADMIN`. |
| Abuse control | **Bucket4j** | Token-bucket rate limits (login, register, reserve). In memory, so single instance only. |
| Payments (server) | **stripe-java** + webhooks | Server creates PaymentIntents and learns the result from signed webhooks, which is the only trustworthy payment signal. |
| Tests | JUnit, H2, **Testcontainers (real Postgres)**, `flutter_test` | The Postgres tests prove the concurrency claims; H2 tests are fast. |

**Net benefit:** correctness lives in the database (atomic statements, unique indexes), correctness of money lives in Stripe webhooks + idempotency, and one Flutter codebase covers every screen.

---

## 3. The key idea in one picture

```
 stock counter  Drop.reservedSlots  must always equal
 count(HELD reservations) + count(CONFIRMED reservations)
```

Everything in the backend exists to keep that sentence true under concurrency:

- **Take a slot:** one SQL statement, `UPDATE drops SET reserved_slots = reserved_slots + 1 WHERE id=? AND reserved_slots < total_slots AND live`. If it updates 0 rows, it's sold out. No read-then-write, so no race.
- **Give a slot back:** `reserved_slots - 1`, but only by whoever *wins* a conditional status change (`HELD -> EXPIRED` etc.), so it happens exactly once.
- **Hand a slot to a waiter:** *don't* decrement; create a new HELD reservation for the waiter in the same transaction. The counter never dips, so nobody can steal it.

---

## 4. Product flow (what the user does) next to what the code does

### 4.1 Happy path: reserve, pay, confirmed

| # | What happens | Where (client) | Where (server) |
| :-- | :--- | :--- | :--- |
| 1 | Home screen shows live drops and remaining slots, refreshed every 4 s | [home_screen.dart](../lib/screens/home_screen.dart), [drops_section.dart](../lib/widgets/drops/drops_section.dart), polling in [drop_state.dart](../lib/models/drop_state.dart) | `GET /drops` -> [DropController.java:30](../backend/src/main/java/com/example/zomato/controller/DropController.java:30) -> `DropService.listUpcomingAndLive` |
| 2 | Customer taps **Reserve** | [drop_detail_screen.dart](../lib/screens/drop_detail_screen.dart) `_reserve` | `POST /drops/{id}/reserve` -> [DropController.java:56](../backend/src/main/java/com/example/zomato/controller/DropController.java:56) (rate-limited) -> [DropService.reserveWithResult](../backend/src/main/java/com/example/zomato/services/DropService.java:168) |
| 3 | A slot is taken atomically and a HELD reservation (expires in 10 min) is saved | | `DropRepository.tryReserveSlot` ([DropRepository.java:19](../backend/src/main/java/com/example/zomato/repository/DropRepository.java:19)), then insert `DropReservation` |
| 4 | Countdown banner appears | [hold_banner.dart](../lib/widgets/drops/hold_banner.dart), [countdown_text.dart](../lib/widgets/drops/countdown_text.dart); time measured against the server's `serverTime`, see `DropState.serverNow` | response carries `expiresAt` and `serverTime` ([ReservationResponseDTO](../backend/src/main/java/com/example/zomato/dto/ReservationResponseDTO.java)) |
| 5 | Customer taps **Pay** -> an unpaid order is created from the hold | [drop_checkout_screen.dart](../lib/screens/drop_checkout_screen.dart) `_pay` -> `OrderService.checkoutDrop` | `POST /orders/checkout?reservationId=` -> [OrderService.checkoutDrop:142](../backend/src/main/java/com/example/zomato/services/OrderService.java:142): price comes from the **drop**, never the client; email must be verified; then [DropService.attachOrder:341](../backend/src/main/java/com/example/zomato/services/DropService.java:341) guarantees at least 5 more minutes |
| 6 | Payment intent created, Stripe sheet shown | [checkout_controller.dart](../lib/controllers/checkout_controller.dart), [payment_service.dart](../lib/services/payment_service.dart) | `POST /payment/create` -> `PaymentService.createPaymentIntent`, which also calls [keepDropHoldAlive](../backend/src/main/java/com/example/zomato/services/PaymentService.java:284) |
| 7 | Stripe tells the server the payment succeeded (signed webhook) | | `POST /payment/webhook` -> [handleStripeWebhook:294](../backend/src/main/java/com/example/zomato/services/PaymentService.java:294) -> [onPaymentSucceeded:393](../backend/src/main/java/com/example/zomato/services/PaymentService.java:393) -> [DropService.confirmByOrderId:396](../backend/src/main/java/com/example/zomato/services/DropService.java:396) (`HELD -> CONFIRMED`, no counter change) |
| 8 | The app polls the order until it is PAID, then shows success | `pollPaymentStatus` in [payment_service.dart](../lib/services/payment_service.dart) | `GET /orders/{id}` |

### 4.2 Hold expires (customer walked away)

`DropReservationScheduler.sweep` (every 15 s) -> [DropService.expireStaleHolds:321](../backend/src/main/java/com/example/zomato/services/DropService.java:321): conditional `HELD -> EXPIRED`, then **free the slot or hand it to a waiter**, and publish `HoldLapsedEvent`. After the transaction commits, [DropEventListener](../backend/src/main/java/com/example/zomato/services/DropEventListener.java) cancels the unpaid order and its Stripe PaymentIntent ([OrderService.cancelOrderForLapsedHold:370](../backend/src/main/java/com/example/zomato/services/OrderService.java:370)). On the phone, the countdown reaches zero, `DropState.refresh()` runs, and the checkout screen switches to "This hold has expired".

### 4.3 Sold out: waitlist and hand-off

1. `POST /drops/{id}/waitlist` -> [joinWaitlist:581](../backend/src/main/java/com/example/zomato/services/DropService.java:581): allowed only if the drop is live, truly full, and the customer holds nothing.
2. Any slot freed anywhere (release, expiry, refund, order cancel) goes through `freeOrHandOff` -> `offerNextWaiter`: takes the oldest `WAITING` entry (by id), marks it `OFFERED`, creates a HELD reservation for them with a 5 min window, **leaves `reservedSlots` alone**, and publishes `WaitlistOfferedEvent` (an in-app notification is saved).
3. The phone's next poll (<= 4 s) sees an `OFFERED` entry plus a HELD reservation: `DropState` flags it, the banner says "A slot opened up for you!".
4. If they ignore it, the offer expires through the same sweeper and cascades to the next person.
5. Safety nets: `promoteWaitlists` (free slot + waiters, e.g. capacity raised) and `expireEndedWaitlists` (drop ended), both run by the same scheduler.

### 4.4 Late payment (the payment-processing race)

| Situation | Result | Code |
| :--- | :--- | :--- |
| Payment is *processing* or in 3-D Secure when the hold is about to end | Hold is extended by 5 min (cap: 20 min from creation) | `payment_intent.processing` / `requires_action` -> `onPaymentInFlight` -> [extendHoldForPayment:379](../backend/src/main/java/com/example/zomato/services/DropService.java:379) |
| Paid after the hold lapsed, slot still free | Slot reclaimed, cancelled order revived | `confirmByOrderId` reclaim path + revive in `onPaymentSucceeded` |
| Paid after the hold lapsed, slot gone (or customer re-reserved) | Order cancelled immediately, refund issued; if the refund fails it is retried with back-off | `processRefund:205`, `retryFailedRefunds:264`, [RefundRetryScheduler](../backend/src/main/java/com/example/zomato/services/RefundRetryScheduler.java) |

### 4.6 Craving search (retrieval, no LLM)

Goal: a customer types what they feel like ("something sweet but also spicy") and sees the top dishes, with why.

| # | What happens | Where |
| :-- | :--- | :--- |
| 1 | Owner adds a dish: name, price, ingredients, veg, spice 0-4, served hot/cold, mood, **at least 2 flavor tags** (live suggestions as they type) | [add_dish_dialog.dart](../lib/widgets/owner/add_dish_dialog.dart) -> `POST /menu-items/suggest-tags` ([MenuItemTagController](../backend/src/main/java/com/example/zomato/search/MenuItemTagController.java)) -> `AutoTagger` |
| 2 | Save: validated, stored, tags saved (`OWNER`, or `AUTO` if none sent), dish indexed at once | `MenuItemService.save` -> `SearchIndexService.onSaved` (tags, BM25, vector) |
| 3 | Customer types in the home search bar; after 450 ms and 3+ characters the app asks the backend | [dish_search_state.dart](../lib/models/dish_search_state.dart) -> `GET /search/dishes` ([SearchController](../backend/src/main/java/com/example/zomato/search/SearchController.java)) |
| 4 | The text is understood: filler removed, "vegetarian" / "under 300" become filters, "sweet but also spicy" becomes two facets | `QueryParser` |
| 5 | Four rankings (embeddings, per-facet embeddings, BM25, tags) are merged with Reciprocal Rank Fusion; dishes covering every flavor get a lift | `HybridSearchService` |
| 6 | The top k come back with matched flavors and reasons built only from real matches; the app lists them under the bar | [dish_results_section.dart](../lib/widgets/search/dish_results_section.dart), [dish_result_card.dart](../lib/widgets/search/dish_result_card.dart) |
| 7 | Tapping a dish opens its restaurant | `_openDish` in [home_screen.dart](../lib/screens/home_screen.dart) |

Key facts: the model (bge-small, 384 dims, ONNX) runs inside the backend; without its files search runs on keywords and
tags (`mode: KEYWORD`). Quality numbers and what was tried: [search-quality-report.md](search-quality-report.md).

### 4.7 The rest of the platform (read less closely by me)

- **Auth:** [ApiAuthController](../backend/src/main/java/com/example/zomato/controller/ApiAuthController.java) (register, login, refresh, Google, email verification), `JwtService`/`JwtFilter` validate the bearer token, [SecurityConfig](../backend/src/main/java/com/example/zomato/config/SecurityConfig.java) decides which URLs are public. Client: `AuthService`, `AuthInterceptor`, `SessionProvider`.
- **Cart and normal orders:** `CartState` + `PureCart` on the client (pure math, offline-friendly), `CartController`/`OrderService.checkout` on the server.
- **Roles:** owner/delivery/admin dashboards ([restaurant_dashboard_screen.dart](../lib/screens/restaurant_dashboard_screen.dart) etc.) call role-guarded endpoints (`@PreAuthorize`).
- **Tracking:** `order_tracking_screen.dart` with `flutter_map`.

---

## 5. Concepts mapped to code

| Concept | One-line meaning | Where it lives |
| :--- | :--- | :--- |
| **Atomic conditional UPDATE** | The database checks and changes in one step, so two requests can't both win | `DropRepository.tryReserveSlot/releaseSlot`; every `transition*` method in [DropReservationRepository](../backend/src/main/java/com/example/zomato/repository/DropReservationRepository.java) |
| **Slot invariant** | `reservedSlots == HELD + CONFIRMED` | Comment block in `DropService`; re-checked by every concurrency test |
| **Partial unique index** | "One live reservation per customer per drop" enforced by the DB, even across servers | created by [DropSchemaInitializer](../backend/src/main/java/com/example/zomato/config/DropSchemaInitializer.java); mirrored in `db/migration` |
| **Idempotency** | Doing the same thing twice has the effect of once | reserve returns the existing hold; webhook event ids stored in `ProcessedWebhookEvent`; Stripe idempotency keys on intents/refunds |
| **Webhook = source of truth** | The client saying "I paid" proves nothing; Stripe's signed event does | `handleStripeWebhook` verifies the signature before anything else |
| **Compensation** | Undo a step when a later step fails | reclaim rollback `CONFIRMED -> CANCELLED`; refund when the slot is lost |
| **Slot hand-off** | Transfer ownership instead of release-then-reacquire | `offerNextWaiter` in `DropService` |
| **Scheduler as single owner** | One component frees slots on a timer so rules can't disagree | [DropReservationScheduler](../backend/src/main/java/com/example/zomato/services/DropReservationScheduler.java); `OrderCleanupScheduler` skips live holds |
| **After-commit side effects** | Emails/Stripe calls happen only once the DB change is safely committed | [DropEventListener](../backend/src/main/java/com/example/zomato/services/DropEventListener.java) with `AFTER_COMMIT`; the notification listener needs `REQUIRES_NEW` or its save is silently lost |
| **Server clock** | The phone's clock can't be trusted | every drop/reservation response has `serverTime`; `DropState._offset` |
| **Polling** | Client asks "what changed?" every 4 s instead of the server pushing | `DropState.retainPolling` (shared timer, reference counted) |
| **Repository pattern (client)** | Screens depend on an interface, tests swap in a fake | [drop_repository.dart](../lib/repositories/drop_repository.dart) / `drop_service.dart` / `test/fakes/fake_drop_repository.dart` |
| **Rate limiting** | Stops hoarding bots | `RateLimitingService.tryConsumeReserve` (Bucket4j) |
| **@DynamicUpdate** | Saving an edited drop must not overwrite `reservedSlots` with a stale copy | [Drop.java](../backend/src/main/java/com/example/zomato/entity/Drop.java) |
| **Hybrid retrieval** | Several independent rankings (meaning, words, tags) merged so one weak signal cannot sink a result | `HybridSearchService` |
| **Reciprocal Rank Fusion** | Combine rankings by rank, not by incompatible scores: `weight / (60 + rank)` summed | `HybridSearchService.search` |
| **Embedding** | Text turned into a 384-number vector; similar meaning means a small angle | `OnnxEmbeddingProvider` (bge-small), query prefix on queries only |
| **BM25** | Classic keyword scoring that rewards rare words; here with plurals, prefixes and typo tolerance | `Bm25Index` |
| **Facets** | "sweet but also spicy" scored as two parts, blended toward the weaker one so a dish must be both | `QueryParser`, facet list in `HybridSearchService` |
| **Flavor tags, owner vs auto** | Owners confirm tags (weight 1.0); the tagger suggests the rest from keyword cues and prototype similarity | `Flavor`, `AutoTagger`, `MenuItemTag.source` |
| **Graceful degradation** | No model file: the dense lists drop out and search still works | `NoEmbeddingProvider`, `SearchConfig` |
| **Contract tests** | Client and server agree on JSON | [test/api_contract_test.dart](../test/api_contract_test.dart) parses JSON captured from a live backend (`test/fixtures`) |

---

## 6. What happens where (layer map)

```
 Flutter app ──HTTP+JWT──▶ Spring Boot API ──SQL──▶ PostgreSQL
   screens                  controllers               drops, drop_reservations,
   DropState (poll 4s)      services (rules)          drop_waitlist, orders, payment ...
   Stripe sheet             schedulers (15s, 60s)           ▲
        │                   event listeners                 │ atomic UPDATEs + unique indexes
        └──card data──▶ Stripe ──signed webhook──▶ /payment/webhook
```

- **Client decides nothing important.** It displays, asks, and counts down. Price, slot ownership, expiry and refunds are all decided server-side.
- **Controller** = thin HTTP edge (auth, rate limit). **Service** = business rules. **Repository** = SQL. **Scheduler** = time-driven rules. **Listener** = side effects after commit.

---

## 7. State machines to remember

**Reservation:** `HELD` -> `CONFIRMED` (paid) | `EXPIRED` (timer) | `CANCELLED` (released/refunded). Late payment can move `EXPIRED/CANCELLED -> CONFIRMED` if a slot is free.

**Waitlist entry:** `WAITING` -> `OFFERED` (slot handed over) -> `CLAIMED` (they started checkout) | `EXPIRED` (ignored / drop ended) | `LEFT` (declined).

**Order payment:** `PENDING` -> `PAID` | `FAILED`; `PAID` -> `REFUNDED` (slot lost or cancelled). Payment record has `REFUND_FAILED` while retries run.

**Timer rule** (all `drops.*` properties): hold 10 min; checkout guarantees >= 5 min; payment in flight extends to now + 5 min; hard cap 20 min from creation; waitlist offer 5 min; sweeper every 15 s.

---

## 8. Things that are easy to forget (or get wrong)

1. **Flyway does not run.** Spring Boot 4 needs its own starter. The schema comes from Hibernate; `DropSchemaInitializer` adds the indexes. The `db/migration` SQL is documentation.
2. **Demo mode** (`SPRING_PROFILES_ACTIVE=demo`) swaps Stripe for a fake gateway; `scripts/demo/pay_order.sh` plays Stripe's webhook. Real Stripe test mode was never run.
3. **Default DB** is Postgres on `localhost:5434/zomato`, not H2. Tests use H2 and Testcontainers.
4. Your own dev backend may already hold port 8080; I used 8090 for demos.
5. Money is stored as `double`; rate limits are in memory; the client polls rather than receiving push.
6. `main` already contains the original (watermarked) commits through PR #2; a revert branch and `drops-client-waitlist-v2` (clean message) exist on origin.
7. `GET /orders` is the customer's own order list (the old `/orders/customer/{id}` never existed).

---

## 9. How to run and check it

- Backend tests: `cd backend && ./mvnw clean verify -Ppostgres` (needs Docker). Flutter: `flutter test` and `dart analyze`.
- Whole flow by hand: README, section "Demo Mode".
- Whole flow by script: `python3 scripts/demo/e2e_drops_smoke.py` (25 checks over real HTTP).
- Evidence and numbers: [concurrency-report.md](concurrency-report.md).

---

## 10. Self-test (you should be able to answer these)

1. Why is `UPDATE ... WHERE reserved_slots < total_slots` safer than reading the count first?
2. Why does a waitlist hand-off *not* decrement `reservedSlots`?
3. Who frees slots on a timer, and what else happens when one is freed?
4. A customer's payment is in 3-D Secure at minute 10. What stops the hold expiring?
5. A customer pays at minute 12 and the plate is gone. What happens, and what if the refund call fails?
6. Why trust the webhook and not the app saying "paid"?
7. Why does the countdown use `serverTime`?
8. Two app servers receive the same customer's reserve at once. What decides the winner?
9. Why must the notification listener use `REQUIRES_NEW`?
10. Why is an embedding model a weak search signal on its own here, and what carries the quality instead?
11. Which parts of the platform (auth, cart, dashboards) did you not change and where would you start reading them?
