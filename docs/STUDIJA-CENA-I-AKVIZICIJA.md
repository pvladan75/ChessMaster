# Cost, plans and acquisition — a study

Written 3.10.2026, after the owner's six decisions of the same day
(`CENA-I-PRETPLATA.md` §7), and rewritten that evening around **one balance of
credits**, on the owner's word. It answers: what a unit of each metered thing
costs, what a plan and a pack contain, what an account earns, where a purchase
happens, how users are acquired and where to advertise, and what the other
three platforms would take.

**Nothing here is built, and no price is decided.** Every figure says where it
comes from. Three kinds:

- **measured** — on this workstation today, or in a plan's own measurements;
- **list price** — read from the provider's page today (or marked *not
  re-read*);
- **assumed** — a guess, stated as one. §11 lists what would replace each.

All money is USD. Income tax is left out throughout: it is a question for an
accountant, and it scales the result without changing any choice below.

---

## 1. What one unit costs

`USAGE_UNIT_COSTS` **is not set in `.env`**, so the server's own cost estimate
(`getUsageReport`, the status tool) reads zero for everything today.
`.env.example` carries four example values and no token prices.

| Item | Unit cost | Kind |
|---|---|---|
| Voice (Agora) | $0.99 per 1,000 person-minutes — $0.059 a person-hour. First 10,000 minutes a month free, for the whole account | list price |
| `deepseek-v4-pro` (position study) | input $0.66–1.32, output $1.98–3.96 per million tokens (off-peak – peak) | list price |
| `deepseek-flash` (tutorial words, review words, translation) | input $0.15–0.30, output $0.60–1.20 per million tokens | list price |
| Film narration (Azure) | $15 per million characters; 500,000 a month free on F0 | list price, *not re-read* |
| Speech to text (Groq) | $0.111 per hour of sound | list price, *not re-read* |
| Recording storage | 1.92 MB a minute (16 kHz mono PCM WAV), 115 MB an hour | measured, 7 files |
| Film storage | about 0.8 MB a minute | measured, 25 films |
| Film rendering, scanner, local tablebase | the droplet's CPU — no cost per use | — |

DeepSeek's peak hours are 01:00–04:00 and 06:00–10:00 UTC on weekdays. The
second window is a European morning, so peak prices are the honest planning
figure for this audience.

### Per action

| Action | Tokens or size | Expected | Worst case |
|---|---|---|---|
| Position study, with translation | 6,950–8,100 tokens (measured), translation about 6,000 (measured: 72,168 over 12) | $0.014 | $0.071 |
| Tutorial words | 15,500 average, 22,800 at most (measured) | $0.007 | $0.055 |
| Review words | not measured — assumed equal to a tutorial | $0.007 | $0.055 |
| Tutorial translation | not measured — assumed equal to a tutorial | $0.007 | $0.055 |
| Film with narration | median 202 s, longest 498 s (measured, films of a minute or more); 900 characters a minute assumed | $0.045 | $0.11 |
| One hour of recording, transcribed | — | $0.11 | $0.11 |
| One hour of recording, kept for a month | 115 MB; $0.10 per GB-month assumed | $0.012 | $0.012 |

*Worst case* means: two attempts (the server's retry), every token billed at
the peak output price, the longest film. *Expected* means: one attempt,
off-peak, the measured average. The split of a study's tokens between input
and output is not known, which is why the worst case bills all of them as
output; a DeepSeek invoice would narrow it.

**What the table says.** Voice is the only cost a trainer runs up by doing
their ordinary work, hour after hour. Every AI action is between one and seven
cents. Storage is small per month but never resets.

A simplification worth flagging, not acting on unasked: recordings are stored
as uncompressed WAV. Opus at speech quality is roughly sixteen times smaller.
It would matter only for the storage row, and `uploads/` is the one directory
where a conversion must not go wrong.

---

## 2. The model: one balance of credits

The owner's word of 3.10.2026, replacing the per-feature allowances of this
study's first version:

- an account has **one balance of credits**, sized by its plan, and spends it
  on whichever paid services it chooses — nobody pays for voice they do not
  use;
- **every account type can buy more**, and the price of a credit depends on
  the account type and on the size of the pack;
- **prices follow what a service is worth to the user**, not what it costs —
  so the scanner, which costs nothing per use, has a price.

Five choices confirmed with it ("all as recommended"):

1. one balance in place of per-feature allowances;
2. one pack product per size, the number of credits depending on the buyer's
   plan — three products a store, not six;
3. voice at zero: it cannot be started on an empty balance, a session already
   in voice runs to its end, and the shortfall comes off next month's credits;
4. plans with monthly credits are built first, packs second;
5. one paid plan at launch; a second only if packs cannot be sold somewhere.

### The rule that keeps it safe

Price by value, with cost as a floor: **each service's price in credits must
keep our worst cost per credit under one figure.** An account's worst case is
then its credits times that figure, whatever it spends them on. When a
provider changes a price, that one figure is what gets checked.

### What can carry a price

Only what the server does. Anything computed on the device — the engine, the
review's judgement — cannot be metered reliably, so the whole board side stays
free by construction. That is decision 1 again, reached from the other side.

### What stays outside the balance

- **Kept recordings.** They accumulate instead of being spent, so they stay a
  cap per plan (decision 3): 30 minutes free, 10 hours on Premium.
- **Homework sends.** They cost nothing; whether the free limit of 5 a month
  stays is the owner's call (§12).

### Rules of the balance

- The monthly credits reset each month; bought credits never expire.
- Monthly credits are spent first, bought ones after.
- A service that fails hands its credits back — the server already does this
  for words it could not write.
- Each paid action shows its price before it runs, and `Usage this month`
  becomes the balance and the price list.

---

## 3. The price list

A **proposal**. One credit is about $0.10 at the plan's rate.

| Service | Credits | Worst cost to us | Cost per credit |
|---|---|---|---|
| Position study or AI comment | 2 | $0.071 | $0.036 |
| Tutorial words from a game | 5 | $0.055 | $0.011 |
| Review words | 3 | $0.055 | $0.018 |
| Tutorial translation | 3 | $0.055 | $0.018 |
| Film export with narration | 5 | $0.11 | $0.022 |
| Transcription, per 10 minutes of sound | 1 | $0.019 | $0.019 |
| Book scan, per 10 pages | 1 | CPU only | — |
| Voice, per person-hour | 2 | $0.059 | $0.030 |

**The figure of §2 is $0.036**, set by the position study. Voice is counted by
the second and charged a credit for every 30 person-minutes; the ledger may
count in smaller units than the screen shows.

What pricing by value says here:

- **Voice has free substitutes** — a phone call, any chat program — so what
  the app's voice is worth is the convenience of one window. It sits near
  cost. This is the owner's own remark about paying for hours not used.
- **The scanner and the AI words have no substitute** and save hours, so they
  carry the margin. A 200-page book is 20 credits, about $2.
- **A film is the thing a student receives**, so it is priced as a result, not
  as a rendering.

Anchors for the plan price, read today: chess.com charges $5.99, $9.99 and
$14.99 a month for its three plans, Chessable $11.99. So $14.99 is the top of
what chess players pay for themselves, and modest for a trainer who is paid
for lessons.

---

## 4. Plans and packs

A **proposal**.

| | Free | Premium, $14.99 a month |
|---|---|---|
| Board side: analysis with the device engine, puzzles, endgames, repertoire, own games, exercises, homework, board-only sessions, Library | yes | yes |
| Credits a month | 10 | 150 |
| Recordings kept (total) | 30 minutes | 10 hours |
| Price of a plan credit | — | $0.100 |
| $4.99 pack gives | 25 ($0.200 each) | 40 ($0.125) |
| $9.99 pack gives | 60 ($0.167) | 90 ($0.111) |
| $19.99 pack gives | 130 ($0.154) | 200 ($0.100) |

Both of the owner's rules hold: a subscriber's credit is cheaper than a free
account's, and a larger pack is cheaper per credit. A pack is never cheaper
than the plan's own credits.

**What 150 credits buy.** For example: 20 one-to-one lesson hours with voice
(80), 10 studies (20), 4 drafted tutorials (20), 4 films (20), with 10 left.
Or 75 person-hours of voice and nothing else. A trainer with five students for
four hours a week uses 96 person-hours, which is 192 credits: the plan and one
$9.99 pack.

**What 10 free credits buy.** Two films, or five studies, or five person-hours
of voice — a taste of each, which is decision 1.

### What changes in the code

Today the server holds a quota per metric (`QUOTAS` in
`entitlementService.js`) and a yes/no right for film export. The model
replaces them with:

- a credit ledger — the monthly grant, debits, hand-backs, bought credits;
- one price list, read by the server and the app from one shared fixture, as
  the puzzle themes already are;
- a debit at each paid route, in the same statement that checks the balance —
  the existing quota code already refuses inside its `UPDATE`;
- voice seconds booked to whoever started the session (decision 2), turned
  into debits;
- the kept-recordings cap (decision 3).

Three things that have **no limit at all today** get one this way: voice,
transcription and translation.

---

## 5. What an account earns

### What a price nets

VAT of 20% inside the displayed price is **assumed** everywhere.

| | $14.99 a month | $4.99 pack |
|---|---|---|
| A store at 15% (Play; Microsoft and Apple as reported) | $10.62 | $3.53 |
| Paddle (5% + $0.50) | $11.37 | $3.45 |
| Dodo Payments (4% + $0.40, +1.5% outside the US, +0.5% on subscriptions) | $11.34 | $3.53 |
| Creem (3.9% + $0.40) | $11.60 | $3.60 |

A web provider nets 7 to 9% more on the subscription and almost nothing more
on a small pack, where the fixed fee eats the difference. The web figures are
before payout fees. Everything below uses the store figure, the worst case.

### Three subscribers

| | Light | Typical | Everything on the costliest service |
|---|---|---|---|
| What they do | 4 hours one-to-one, 5 studies, 1 tutorial, 1 film | 12 hours one-to-one, 10 studies, 4 tutorials, 4 reviews, 4 films, 1 hour transcribed | 75 studies |
| Credits used | 36 | 126 | 150 |
| **Cost** | **$0.61** | **$1.95** | **$5.45** |
| **Left of $10.62** | **$10.01** | **$8.67** | **$5.17** |

The first two rows use expected prices and **assumed** usage — nobody but the
owner has used the app. The third is credits times the figure of §2, plus ten
hours of kept recordings.

- **Credits not used are margin.** The monthly balance resets, so the light
  subscriber's 114 unused credits cost nothing.
- **A yearly plan** at $149.99 nets $8.85 a month and leaves $3.40 in the
  worst case, $6.90 for the typical subscriber.
- **The free tiers of Agora and Azure cover the start.** 10,000 voice minutes
  is 167 person-hours; 500,000 characters is over a hundred median films.

### A free account

Ten credits cost at most $0.36 a month. Ten students who each spent every free
credit on the costliest service would cost $3.60 — under their trainer's
worst-case margin, where the per-feature version of this study had $6.50. A
student mostly solves, plays and watches, which costs nothing; *cost per free
account* is still the figure to watch from the first real month.

### A pack

| Pack | Free account: left after worst cost | Premium: left after worst cost |
|---|---|---|
| $4.99 (nets $3.53) | $2.64 | $2.11 |
| $9.99 (nets $7.08) | $4.95 | $3.88 |
| $19.99 (nets $14.16) | $9.54 | $7.06 |

### Break-even

The droplet costs **$30 a month** (the owner, 3.10.2026: 2 GB of memory, one
AMD vCPU, a 50 GB disk). Whether the managed database and the domain are
inside that figure was not said; if they are billed on top, add them. With a
typical margin of $8.67:

> subscribers to cover fixed costs = fixed monthly cost ÷ 8.67

For $30 that is 3.5 — **four subscribers**; each further $8.67 of fixed cost
is one more.

**The disk is the first ceiling, before any bill.** Kept recordings are the
one thing that accumulates: 1.15 GB for a Premium account at its full ten
hours, 58 MB for a free one at its thirty minutes. How much of the 50 GB is
free on the droplet was not measured; if 30 GB are, that is 26 Premium
accounts at the full cap. Past that the choice is a larger disk or compressed
sound (§1). One vCPU also renders one film at a time — a limit on how many
exports can run in an hour, not a cost, and not measured either.

### What a subscriber is worth over time

Lifetime value is margin divided by monthly churn. Churn is **assumed**; the
only benchmark found says 40–60% of cancellations fall in the first 90 days.

| Monthly churn | Average lifetime | Value at $8.67 a month |
|---|---|---|
| 8% | 12.5 months | $108 |
| 15% | 6.7 months | $58 |

A common rule is to spend at most a third of that to win the customer: **$19
to $36 per paying trainer.** That number governs §7 and §8.

---

## 6. Where a purchase happens

The owner chose Paddle for Windows on 3.10.2026 and the same day asked for
alternatives, after one finding: **Paddle's acceptable-use policy prohibits
virtual currency and stored value** — store credit, gift cards, vouchers — and
does not say whether credits for a seller's own software count. Monthly
credits inside a subscription are not in question; bought packs are.

### By platform

| Platform | Route | Fee | State |
|---|---|---|---|
| Android | Google Play Billing | 15% | built on both ends; no real purchase yet |
| Windows | **the Microsoft Store's own in-app purchase** (recommended), or a web checkout | 15% as reported, or 5–6% and a fixed part | nothing built |
| iOS, macOS (§9) | Apple's in-app purchase — mandatory there | 15% under the small-business programme, and $99 a year | not built |
| Linux, a web build (§9) | a web checkout — no Linux store sells a subscription | 5–6% and a fixed part | the only case that needs a web provider |

**A store wherever one exists; a web provider only where none does.** Every
store is the merchant of record — it takes the payment, handles the tax and
pays out — sells consumable products as a matter of course, so a credit pack
is an ordinary item, and puts the purchase inside the app instead of behind
"visit our website". On the server each is one more adapter behind
`entitlementService.js`, which was written for that.

### The Microsoft Store route

What is known:

- Serbia is on Microsoft's list of countries paid for Store sales, by
  transfer, monthly, from $50 (Microsoft's payout page, read today).
- Subscriptions and consumable add-ons work in a packaged desktop app through
  `Windows.Services.Store`.
- Two Flutter plugins for it exist on pub.dev, both young
  (`flutter_windows_iap` 0.0.1, `windows_store_iap` 0.2.0). Neither was
  evaluated.
- The server checks a purchase by asking Microsoft's collection and purchase
  APIs, with an application registered in Entra ID. No notification stream
  like Play's was found: the server asks, it is not told.

What is not known: whether an Individual account may sell through the Store's
own purchase API at all. The question sent to Microsoft on 3.10.2026 described
an app that does *not* use it, so the ticket needs that one question added.

### Web providers, for when one is needed

| Provider | A seller who is an individual in Serbia | Credit packs | Fee | Note |
|---|---|---|---|---|
| **Paddle** | accepted; individuals skip business verification | the policy above — needs a written answer | 5% + $0.50 | established; pays monthly from $100 |
| **Dodo Payments** | Serbia is on its list, and an individual verifies with their own ID | a built-in feature | 4% + $0.40, +1.5% outside the US, +0.5% on subscriptions; $5 on a payout under $1,000 | young; its policy refuses coaching sold as a service, which this is not |
| **Creem** | Serbia is on its payout list; individuals not confirmed | not addressed | 3.9% + $0.40; payout fee of 7 or 1% | young |
| Lemon Squeezy | pays out to Serbian banks | not addressed | 5% + $0.50 | being moved into Stripe Managed Payments, which does not take a Serbian seller |
| Polar | Serbia is on its list | — | from 5% + $0.50 | **out**: its policy refuses services used by or meant for people under 18 |
| Stripe Managed Payments | no | — | — | out |
| FastSpring | has individual accounts; Serbia not confirmed | unknown | by quote | would have to be asked |

Two things every provider's review will look at, whichever it is:

- **The product is software, not coaching.** Several policies refuse human
  services. The site and the application must say plainly that nothing is
  sold but the app — no lessons, no money between users.
- **Users aged 13 to 17.** The buyer is an adult — a trainer or a parent — but
  the app has younger accounts. One provider refuses that outright; the others
  must be told and asked.

### Recommendation

Windows through the Microsoft Store's own purchases, if Microsoft's answer
allows it and a short trial shows a Flutter app can buy a subscription and a
consumable there. A web provider only if that fails or when a platform
without a store ships — Paddle if it accepts packs, Dodo Payments otherwise.
With plans built before packs (choice 4), neither answer blocks the first
step.

---

## 7. Acquisition: who, and why ads for installs do not pay

**The paying unit is a trainer.** A student costs nothing to win — the trainer
brings them — and pays little or nothing. So the question is never "what does
an install cost" but "what does a trainer who subscribes cost". A free account
that buys a pack is revenue too, but small and unpredictable; the arithmetic
is done on the subscription.

Run it for a broad install campaign:

- an Android install in Europe costs somewhere between $0.66 (a general
  benchmark) and $1.80–4.50 (Google App campaigns, non-gaming, US);
- most people who install a chess app are players, not trainers;
- freemium products convert about 3.7% of users to paid on average.

At $1 an install and 1% of installs becoming paying trainers, a subscriber
costs $100 — three to five times the ceiling. Broad install advertising loses
money at this price. Advertising pays only where the audience is already
trainers, or where the cost is the owner's time instead of money.

### Three constraints before any channel

1. **The country list comes first.** The parent-consent wording is approved
   for Serbia only. An ad shown where the app cannot lawfully take a younger
   user's account is money spent on a refusal.
2. **Ads address adults only** — trainers and parents — in targeting and in
   wording. The major ad platforms restrict targeting under 18 in any case.
3. **Nothing can be measured yet.** The app has no install attribution. An
   advertising SDK changes the privacy policy and touches the accounts of
   users under 18. The cheap alternative: one link per channel to the site,
   and an optional "how did you hear about us" at sign-up, counted on the
   server.

### The measure

One number per channel: **cost per trainer who held a session with at least
one student.** That is the moment the app has done what it is for; installs
and sign-ups are steps on the way.

---

## 8. Channels

### Free, and first

| Channel | Why | Note |
|---|---|---|
| **The app's own films** | A free account's exported film can end on a card naming the app; Premium removes it. Every film a trainer sends or posts is then an advertisement that cost nothing | needs a decision and a small change to the film (§12) |
| **Coach directories** — Lichess (1,502 coaches in mid-2023, about 1,000 teaching in English), Chess.com, FIDE | the only places where the audience is trainers and nothing else | personal messages, a few a day; each platform's rules on unsolicited contact were not read |
| **Serbian clubs and chess schools** | the home market, the approved legal text, the owner's language | in person or by mail |
| **Store listings** | people search "chess coach", "chess lessons" in both stores | the listing text is the whole cost |
| **The owner's existing Play app** | cross-promotion between two apps under one account, already noted in the handoff as the cheapest channel | — |
| **Communities** — r/chess, Lichess and Chess.com forums | where players and coaches talk | each has self-promotion rules, not read; one honest post, not a campaign |

### Paid, as small tests

Each test has a fixed budget of $50–150 and one question. A channel that
produces no trainer with a session for its budget is dropped.

| Order | Platform | What it reaches | Cost signal | Verdict |
|---|---|---|---|---|
| 1 | **Google Ads, search** | people typing "chess coaching software", "online chess lesson tool" | not found; low volume expected | the only paid channel with trainer intent — test first |
| 2 | **Sponsoring a small chess YouTube channel run by a coach** | that coach's audience, which includes other coaches and serious students | $50–500 for an integration on a channel of 1–10 thousand subscribers; education sponsorship $20–40 per thousand views | one test, with a channel whose host actually uses the app |
| 3 | **Reddit ads on r/chess** | chess players; a minority teach | from $5 a day; $0.50–2.50 a click | cheap to test, weak targeting |
| 4 | **Microsoft Store Ads** | people searching the Store on Windows | not found | only after the Store release; small volume |
| 5 | **Google App campaigns** | Android installs, optimised by Google | $0.66–4.50 an install | only with an in-app conversion event to optimise for, which needs the SDK of constraint 3 |
| 6 | **Meta (Facebook, Instagram)** | parents and coaches by interest | $12–18 per thousand impressions | no intent; later, if at all |
| — | LinkedIn, TikTok | — | $25–60 per thousand; a young audience | not for this product |

### Order of work

1. The backend live, the store listings up, the price live, the site with its
   terms and privacy pages.
2. Channel links and the sign-up question, so every later step can be counted.
3. The free channels, for a month. They answer the two unknowns that decide
   everything else: how many trainers who try the app hold a session, and how
   many of those subscribe.
4. Paid tests in the order above, one at a time, each against the ceiling of
   §5.

---

## 9. The other three platforms

The app runs on Android and Windows. The project already holds the folders for
iOS, macOS, Linux and the web, and the code branches by platform in few
places — ten checks for Windows in eight files.

**Why it bears on acquisition.** The paying unit is a trainer, and a trainer
adopts the app only if *all* their students can open it. Phones on iOS are 26%
in Serbia, 39% in Europe and 58% in the United States (StatCounter, mid-2026).
Outside Serbia a trainer with ten students almost certainly has some who
cannot join today.

| | iOS and iPadOS | macOS | Linux |
|---|---|---|---|
| Reach it adds | 26–58% of phones, and the tablets many students use | about 16% of desktops worldwide | about 4% of desktops |
| Already there | the engine package declares iOS; voice, purchases, sound and recording plugins all support it; the phone layouts | the desktop layouts; voice, sound and recording plugins support it | the engine's process route and the desktop Google sign-in already name Linux |
| Missing | the engine was never built for it; sign-in rules (below); nothing was ever run | an engine — Windows downloads its engine, which a sandboxed Mac app cannot; the password store is Windows-only | **the voice SDK does not support Linux**; an engine download; a password store; packaging for several distributions |
| Purchases | Apple's, mandatory | Apple's | a web checkout only |
| Needs | a Mac to build and sign, an iPhone or iPad to test, the developer programme at $99 a year | the same Mac and programme | nothing to buy |

What Apple's review will ask of this app in particular (its guidelines, read
today):

- **Sign in with Apple, or an equivalent**, beside Google sign-in — or no
  Google sign-in on Apple devices;
- **account deletion inside the app** — and no route for deleting one's own
  account exists yet on the server either (`STANJE-RADA.md` records it as
  open). Google Play asks the same of any app with accounts, so this one is
  due **before the Android release**, not only for Apple;
- **reporting and blocking** another user, for an app where people talk — a
  search of the app found neither. Sessions hold only a trainer and their own
  accepted students, which may soften the demand and does not remove it.

Whether an individual in Serbia enrolls in Apple's programme without trouble
was not confirmed; the official pages do not exclude Serbia, and two forum
reports describe identity checks that failed there.

**The real cost is not the port.** It is that every feature then has to be
watched running on five targets instead of two, by one person. The live-check
list holds hundreds of items for two.

**Order, if at all:** nothing before the first paying trainers on the two
platforms that exist. Then iOS, for the reason above; macOS right after it,
since the Mac, the programme and the purchase adapter are then already paid
for; Linux last, and without voice it is a lesser product — a web build would
reach Linux and school Chromebooks together, and is a larger port than any of
the three.

---

## 10. What the study recommends

- **Model:** one balance of credits (§2), with the price list of §3 as a
  first guess at value and $0.036 a credit as the cost floor.
- **Plans:** free with 10 credits, Premium at $14.99 with 150, three packs
  (§4). Plans first, packs second.
- **Where to buy:** a store wherever one exists — Play on Android, the
  Microsoft Store on Windows — and a web provider only where none does (§6).
- **Acquisition:** trainers only; free channels first; the film end card;
  paid tests small and in order, never before attribution exists.
- **Platforms:** iOS after the first paying trainers, macOS behind it, Linux
  last (§9).
- **Before any of it:** set `USAGE_UNIT_COSTS` from invoices; build the route
  by which a user deletes their own account, which both stores require.

---

## 11. What is assumed, and what would replace it

| Assumption | Replace with |
|---|---|
| The price list is a guess at what each service is worth | what people actually spend credits on, and which packs they buy |
| A study's tokens all billed as output | the first DeepSeek invoice, or the input/output split from the API's answer |
| Review and translation tokens equal a tutorial's | `ai_review_tokens`, `ai_translation_tokens` after a few real runs |
| 900 narration characters a minute | `tts_azure_characters` against the lengths of the films made |
| Azure and Groq list prices | their pages or an invoice |
| $0.10 per GB-month of storage — the droplet's 50 GB disk is already paid for, so this is the price of space past it | the free space on the droplet, and the provider's price for a volume |
| 20% VAT inside the price everywhere | the first Play payout report; each provider's documentation |
| 15% at the Microsoft Store and at Apple | the developer agreements |
| Light and typical usage | the first month with real subscribers |
| Churn of 8–15% a month | three months of subscriptions |
| Fixed costs beyond the droplet's $30 — the managed database, the domain | the owner's invoices |
| Install costs and conversion rates | the free channels' first month |
| Dodo Payments and Creem are sound enough to hold revenue | their track record, before either is used |

---

## 12. Decisions this leaves for the owner

Decided on 3.10.2026: the model of §2 and its five choices. Still open:

1. The price list in credits (§3) — the values are a first guess.
2. The plan: $14.99 for 150 credits, 10 for a free account, the yearly price.
3. The packs: three sizes, and how many credits each gives each account type.
4. Where a Windows purchase happens (§6) — after Microsoft's and Paddle's
   answers.
5. Whether the free tier's limit of 5 homework sends stays, though it costs
   nothing.
6. Whether a free account's film ends on a card naming the app (§8).
7. The country list — which also bounds where anything is advertised.
8. Whether to accept an advertising SDK in the app, or measure by links and a
   question only (§7).
9. Whether and when the other platforms follow (§9).

---

## Sources

Read 3.10.2026.

- Agora voice pricing — <https://www.agora.io/en/pricing/voice-calling>
- DeepSeek models and pricing — <https://api-docs.deepseek.com/quick_start/pricing>
- Google Play service fees — <https://support.google.com/googleplay/android-developer/answer/112622>
- Microsoft Store payouts by country — <https://learn.microsoft.com/en-us/partner-center/marketplace-offers/payment-thresholds-methods-timeframes>
- Microsoft Store policies — <https://learn.microsoft.com/en-us/windows/apps/publish/store-policies>
- Microsoft Store purchases checked from a service — <https://learn.microsoft.com/en-us/windows/uwp/monetize/view-and-grant-products-from-a-service>
- Microsoft Store fee, as reported — <https://www.techradar.com/pro/microsoft-just-dropped-its-store-fees-for-windows-developers>
- Flutter plugins for Store purchases — <https://pub.dev/packages/flutter_windows_iap>, <https://pub.dev/packages/windows_store_iap>
- Paddle acceptable use policy — <https://paddle.com/support/aup>
- Paddle fees, third-party summary — <https://dodopayments.com/blogs/paddle-fees-explained>
- Dodo Payments: countries, pricing, merchant acceptance — <https://docs.dodopayments.com/miscellaneous/accepted-countries-and-territories>, <https://dodopayments.com/pricing>, <https://docs.dodopayments.com/miscellaneous/merchant-acceptance>
- Creem: countries, prohibited products — <https://docs.creem.io/merchant-of-record/supported-countries>, <https://docs.creem.io/faq/prohibited-products>
- Polar: countries, acceptable use, fees — <https://polar.sh/docs/merchant-of-record/supported-countries>, <https://polar.sh/docs/merchant-of-record/acceptable-use>, <https://polar.sh/docs/merchant-of-record/fees>
- Lemon Squeezy prohibited products — <https://docs.lemonsqueezy.com/help/getting-started/prohibited-products>
- Stripe Managed Payments eligibility — <https://docs.stripe.com/payments/managed-payments/eligibility>
- Chess.com plans — <https://support.chess.com/en/articles/8562418>
- Apple's review guidelines — <https://developer.apple.com/app-store/review/guidelines/>
- Apple's small-business programme — <https://www.revenuecat.com/docs/platform-resources/apple-platform-resources/app-store-small-business-program>
- Agora's Flutter SDK platforms — <https://docs.agora.io/en/realtime-media/rtc/reference/supported-platforms/flutter>
- Mobile and desktop shares — <https://gs.statcounter.com/os-market-share/mobile/serbia>, <https://gs.statcounter.com/os-market-share/mobile/europe>, <https://gs.statcounter.com/os-market-share/mobile/united-states-of-america>, <https://gs.statcounter.com/os-market-share/desktop/worldwide>
- Install cost benchmarks — <https://www.adjust.com/blog/ecpi-benchmarks/>,
  <https://semnexus.com/cpi-benchmarks-app-category-platform-2026/>
- Freemium and trial conversion — <https://userpilot.com/blog/saas-average-conversion-rate>,
  <https://visionary-marketing.co.uk/blog/saas-free-trial-conversion-statistics-2026>
- Reddit ad costs — <https://stackmatix.com/blog/reddit-ads-cost-guide-2026>
- YouTube sponsorship rates — <https://www.collabpals.com/tools/youtube-sponsorship-rate-calculator>
- Microsoft Store Ads availability — <https://ppc.land/microsoft-advertising-expands-in-europe-and-south-africa/>
- Lichess coach count — <https://lichess.org/ublog/KvYjULSR/redirect>
