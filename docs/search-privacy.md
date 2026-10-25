# Search privacy: what is counted, and how to turn it off

This is the customer-facing description. The app shows a short version of it above the first search results and in Profile, "Help improve search".

## What we count

When you search, tap a result or add a dish from a search to your cart, we record, **without your name, email, phone, address or device id**:

- the words you typed, cleaned up (for example "late night noodles" becomes "noodle"),
- whether the menus could answer it,
- which dishes were shown, and whether one was tapped or added,
- if that order is later delivered, one more order for that kind of search.

It is used for two things: showing restaurants what customers are craving (rising searches, dishes worth adding, how much search brings in), and showing "Trending cravings" to other customers.

## How it stays anonymous

- Searches are tied to a **random key that changes every day**, made from a code that stays on your device plus a server secret. It can say "ten different people searched this today", but it cannot follow you from one day to the next.
- A search never carries your account. Orders are not linked to the words you typed: an order only adds one to a count for a kind of search ("birria taco"), and only once it is delivered. The link between your order and that kind of search is held for the hours the order is in flight, then deleted.
- Raw search text is deleted after 90 days. Only counts remain.
- Restaurants see counts and example wordings, never who searched.
- Trending shows only searches that many people made over several days.

## Turning it off

Profile, **Help improve search**, off. The app then:

- tells the server "Do Not Track" with every search, so nothing about it is recorded,
- sends no anonymous code,
- reports no taps,
- attaches no search to cart adds, so no order is ever linked to a search.

Search, trending and ordering work exactly the same. The choice is stored on your device.

## For developers

The server honours the standard `DNT: 1` header on `/search/dishes`, `/search/events/{id}/click` and `/cart/items`, and `search.log.enabled=false` turns logging off for everyone.
The app's switch is `SearchPrivacy` (`lib/services/search_privacy.dart`). See `docs/search-insights.md` for the data model and retention.
