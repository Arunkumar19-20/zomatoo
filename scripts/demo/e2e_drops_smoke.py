#!/usr/bin/env python3
"""Live smoke test of the drops flow against a running backend (demo profile, real Postgres).

Exercises reserve, idempotency, sold out, waitlist hand-off, checkout, payment webhook, hold expiry and the
late-payment refund over real HTTP, checks the slot-accounting invariant in the database, and refreshes the
JSON fixtures in test/fixtures that test/api_contract_test.dart parses with the Flutter DTOs.

Setup (see README, "Demo mode"): backend with SPRING_PROFILES_ACTIVE=demo and STRIPE_WEBHOOK_SECRET=whsec_demo_e2e,
and a Postgres container whose name is in CRAVEY_PG (default cravey_e2e_pg, database cravey_e2e).

    API_BASE_URL=http://localhost:8090 python3 scripts/demo/e2e_drops_smoke.py
"""
import json, os, subprocess, sys, time, urllib.request, urllib.error

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BASE = os.environ.get("API_BASE_URL", "http://localhost:8080")
WEBHOOK_SECRET = os.environ.get("STRIPE_WEBHOOK_SECRET", "whsec_demo_e2e")
PG_CONTAINER = os.environ.get("CRAVEY_PG", "cravey_e2e_pg")
PG_DB = os.environ.get("CRAVEY_PG_DB", "cravey_e2e")
FIX = os.path.join(ROOT, "test", "fixtures")
os.makedirs(FIX, exist_ok=True)
fails = []

def call(method, path, token=None, body=None, expect=None):
    req = urllib.request.Request(BASE + path, method=method)
    req.add_header("Content-Type", "application/json")
    if token: req.add_header("Authorization", "Bearer " + token)
    data = json.dumps(body).encode() if body is not None else None
    try:
        with urllib.request.urlopen(req, data=data, timeout=20) as r:
            raw = r.read().decode(); code = r.status
    except urllib.error.HTTPError as e:
        raw = e.read().decode(); code = e.code
    js = json.loads(raw) if raw.strip().startswith(("{", "[")) else raw
    if expect is not None and code != expect:
        fails.append(f"{method} {path}: expected {expect} got {code} {raw[:200]}")
    return code, js

def check(name, cond, detail=""):
    print(("PASS " if cond else "FAIL ") + name + (f"  [{detail}]" if detail and not cond else ""))
    if not cond: fails.append(name + " " + str(detail))

def sql(q):
    out = subprocess.run(["docker","exec",PG_CONTAINER,"psql","-U","postgres","-d",PG_DB,"-At","-c",q],capture_output=True,text=True)
    return out.stdout.strip()

def login(email, pw="Password123!"):
    c, js = call("POST", "/api/auth/login", body={"email": email, "password": pw})
    return js["accessToken"] if c == 200 else None

def register(name, email):
    call("POST", "/api/auth/register", body={"name": name, "email": email, "password": "Password123!"})
    sql(f"update users set email_verified=true where email='{email}'")
    return login(email)

def pay(order_id, amount, event="payment_intent.succeeded"):
    env = dict(os.environ, API_BASE_URL=BASE, STRIPE_WEBHOOK_SECRET=WEBHOOK_SECRET)
    r = subprocess.run([os.path.join(ROOT, "scripts", "demo", "pay_order.sh"), str(order_id), str(amount), event],capture_output=True,text=True,env=env)
    return r.stdout

def save(name, js):
    json.dump(js, open(f"{FIX}/{name}.json", "w"), indent=2)

# a freshly started backend seeds users and the restaurant a moment after it starts answering requests
admin, rid = None, None
for _ in range(30):
    admin = admin or login("admin@cravey.com")
    rest = call("GET", "/restaurants")[1]
    items = rest["content"] if isinstance(rest, dict) and "content" in rest else rest
    if admin and items:
        rid = items[0]["id"]
        break
    time.sleep(2)
if rid is None:
    sys.exit("backend has no seeded admin/restaurant; is it the demo database?")
print("restaurant", rid)

def new_drop(title, slots):
    later = time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(time.time() + 7200))
    start = time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(time.time() - 60))
    c, js = call("POST", "/drops", admin, {"title": title, "description": "E2E", "price": 24.5, "restaurantId": rid, "startsAt": start, "endsAt": later, "totalSlots": slots}, expect=201)
    return js

d1 = new_drop("E2E Wagyu Drop", 2)
did = d1["id"]
save("api_drop", d1)

alice = register("Alice E2E", "alice.e2e@cravey.com")
bob = register("Bob E2E", "bob.e2e@cravey.com")
carol = register("Carol E2E", "carol.e2e@cravey.com")
dave = register("Dave E2E", "dave.e2e@cravey.com")
check("users can log in", all([alice, bob, carol, dave]))

# --- reserve + idempotency
c, a1 = call("POST", f"/drops/{did}/reserve", alice, expect=201)
save("api_reservation_held", a1)
c2, a2 = call("POST", f"/drops/{did}/reserve", alice)
check("reserve is idempotent (200, same hold)", c2 == 200 and a2["reservationId"] == a1["reservationId"])
c, b1 = call("POST", f"/drops/{did}/reserve", bob, expect=201)
c, drop = call("GET", f"/drops/{did}")
check("drop is sold out with 0 remaining", drop["remainingSlots"] == 0 and drop["status"] == "SOLD_OUT", drop)
c, err = call("POST", f"/drops/{did}/reserve", carol)
check("third customer gets 409 SOLD_OUT", c == 409 and err.get("code") == "SOLD_OUT", err)
save("api_error_sold_out", err)

# --- waitlist
c, w1 = call("POST", f"/drops/{did}/waitlist", carol, expect=201)
c, w2 = call("POST", f"/drops/{did}/waitlist", dave, expect=201)
check("waitlist positions 1 and 2", w1["position"] == 1 and w2["position"] == 2, (w1, w2))
save("api_waitlist_waiting", w1)
c, wdup = call("POST", f"/drops/{did}/waitlist", carol)
check("joining twice is idempotent", wdup["entryId"] == w1["entryId"])

# --- alice releases -> slot handed to carol, never visible as free
c, _ = call("DELETE", f"/drops/reservations/{a1['reservationId']}", alice, expect=204)
c, drop = call("GET", f"/drops/{did}")
check("slot handed off: still 0 remaining", drop["remainingSlots"] == 0, drop)
c, carol_res = call("GET", "/drops/reservations/mine", carol)
check("carol now holds a slot", len(carol_res) == 1 and carol_res[0]["status"] == "HELD", carol_res)
c, carol_w = call("GET", "/drops/waitlist/mine", carol)
check("carol's waitlist entry is OFFERED", carol_w[0]["status"] == "OFFERED" and carol_w[0]["reservationId"] == carol_res[0]["reservationId"], carol_w)
save("api_waitlist_offered", carol_w[0])
c, dave_w = call("GET", "/drops/waitlist/mine", dave)
check("dave moved up to position 1", dave_w[0]["position"] == 1, dave_w)
c, err = call("POST", f"/drops/{did}/reserve", dave)
check("nobody can snipe the handed-off slot", c == 409 and err.get("code") == "SOLD_OUT", err)
note = sql("select count(*) from notification n join users u on u.user_id = n.user_id "
           "where u.email = 'carol.e2e@cravey.com' and n.type = 'DROP_SLOT_OFFERED'")
check("carol was notified about her offer", note.isdigit() and int(note) >= 1, note)

# --- bob pays (checkout + intent + webhook)
c, order = call("POST", f"/orders/checkout?reservationId={b1['reservationId']}", bob, expect=200)
save("api_order_pending", order)
check("order priced from the drop", abs(order["totalAmount"] - 24.5) < 0.001 and order["paymentStatus"] == "PENDING", order)
c, intent = call("POST", f"/payment/create?orderId={order['orderId']}", bob, expect=200)
check("payment intent has client secret", bool(intent.get("clientSecret")), intent)
save("api_payment_intent", intent)
c, again = call("POST", f"/orders/checkout?reservationId={b1['reservationId']}", bob)
check("second checkout for same hold is rejected", c == 409, (c, again))
out = pay(order["orderId"], 24.5)
check("webhook accepted", "HTTP 200" in out, out)
c, o2 = call("GET", f"/orders/{order['orderId']}", bob)
check("order PAID", o2["paymentStatus"] == "PAID", o2)
save("api_order_paid", o2)
c, bob_res = call("GET", "/drops/reservations/mine", bob)
check("bob's reservation CONFIRMED", bob_res and bob_res[0]["status"] == "CONFIRMED", bob_res)

# --- carol leaves while offered -> dave gets it
c, _ = call("DELETE", f"/drops/{did}/waitlist", carol, expect=204)
c, dave_res = call("GET", "/drops/reservations/mine", dave)
check("dave got the slot when carol declined", dave_res and dave_res[0]["status"] == "HELD", dave_res)
c, drop = call("GET", f"/drops/{did}")
check("accounting: 2 of 2 slots used (1 confirmed + 1 held)", drop["remainingSlots"] == 0 and drop["totalSlots"] == 2, drop)
inv = sql(f"select (select reserved_slots from drops where id={did}) || '/' || (select count(*) from drop_reservations where drop_id={did} and status in ('HELD','CONFIRMED'))")
check("DB invariant reserved_slots == active reservations", inv.split("/")[0] == inv.split("/")[1], inv)

# --- hold expiry cancels the unpaid order, then late payment is refunded
d2 = new_drop("E2E Expiry Drop", 1)["id"]
erin = register("Erin E2E", "erin.e2e@cravey.com")
frank = register("Frank E2E", "frank.e2e@cravey.com")
c, e1 = call("POST", f"/drops/{d2}/reserve", erin, expect=201)
c, eorder = call("POST", f"/orders/checkout?reservationId={e1['reservationId']}", erin, expect=200)
# checkout guarantees at least 5 minutes to pay, so force the lapse in the database instead of waiting
sql(f"update drop_reservations set expires_at = now() - interval '1 minute' where id={e1['reservationId']}")
deadline = time.time() + 90
state = None
while time.time() < deadline:
    c, o = call("GET", f"/orders/{eorder['orderId']}", erin)
    state = o["status"]
    if state == "CANCELLED": break
    time.sleep(3)
check("sweeper expired the hold and cancelled the unpaid order", state == "CANCELLED", state)
c, drop2 = call("GET", f"/drops/{d2}")
check("slot returned to the pool", drop2["remainingSlots"] == 1, drop2)
c, f1 = call("POST", f"/drops/{d2}/reserve", frank, expect=201)
out = pay(eorder["orderId"], 24.5)   # erin's late payment arrives; frank owns the only slot
c, o3 = call("GET", f"/orders/{eorder['orderId']}", erin)
check("late payment with slot lost -> order CANCELLED and refunded", o3["status"] == "CANCELLED" and o3["paymentStatus"] == "REFUNDED", o3)
c, drop2 = call("GET", f"/drops/{d2}")
check("frank keeps his slot", drop2["remainingSlots"] == 0, drop2)
save("api_order_refunded", o3)

print("\nFAILURES:" if fails else "\nALL E2E CHECKS PASSED", *fails, sep="\n")
sys.exit(1 if fails else 0)
