# Cost, plans and acquisition — a study

Written 3.10.2026, after the owner's six decisions of the same day
(`CENA-I-PRETPLATA.md` §7) and the choice of Paddle for Windows. It answers
five questions: what a unit of each metered thing costs, what each account
type includes, whether allowances can be topped up, what an account earns, and
how users are acquired — including where to advertise.

**Nothing here is built, and no price is decided.** Every figure says where it
comes from. Three kinds:

- **measured** — on this workstation today, or in a plan's own measurements;
- **list price** — read from the provider's page today (or marked *not
  re-read*);
- **assumed** — a guess, stated as one. §8 lists what would replace each.

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

## 2. What each account type includes

Decisions 1 and 5: free is everything that costs nothing plus a taste of what
is metered; one paid tier to start. The numbers below are a **proposal**.

| | Free | Premium |
|---|---|---|
| Board, analysis with the device engine, puzzles, endgames, repertoire, own games, exercises, homework, board-only sessions, Library | yes | yes |
| Voice in a session one starts | 60 person-minutes a month | 2,000 person-minutes (33 person-hours) |
| Position studies and AI comments (one shared number) | 3 | 20 |
| Tutorial words | 1 | 5 |
| Review words | 1 | 5 |
| Tutorial translations | 0 | 5 |
| Film exports | 2 | 5 |
| Recording transcribed (new, per month) | 20 minutes | 3 hours |
| Recordings kept (total) | 30 minutes | 10 hours |
| Joining a session, receiving films and homework | yes | yes |

Three things in the code today disagree with this and would change:

- the paid tier's placeholder quotas — 500 AI comments, 30 each of studies,
  tutorials and reviews — cost up to $7 at worst-case prices before voice is
  counted;
- translation, speech to text and voice have **no limit at all**;
- the free tier's 5 homework sends a month limit something that costs
  nothing, which decision 1 says is free. Whether it stays as a reason to
  subscribe is the owner's call (§9).

### Worst case per account, per month

| | Free | Premium |
|---|---|---|
| Voice | $0.06 | $1.98 |
| Studies and comments | $0.21 | $1.42 |
| Tutorial words | $0.06 | $0.28 |
| Review words | $0.06 | $0.28 |
| Translations | — | $0.28 |
| Films | $0.22 | $0.55 |
| Transcription | $0.04 | $0.33 |
| Kept recordings | $0.01 | $0.12 |
| **Total** | **$0.65** | **$5.23** |

The Premium total is sized to decision 5's rule (§4): at most half of what a
subscription nets.

**The free tier is the acquisition budget in disguise.** A paying trainer
brings students, and each is a free account. Ten students who each used every
free allowance would cost $6.50 a month — more than the trainer's margin in
the worst case. In practice a student solves, plays and watches, which costs
nothing; but the figure to watch from the first real month is *cost per free
account*, and the free AI and film numbers are the dials.

---

## 3. Topping up an allowance

Decision 4 said: only once somebody actually hits a limit. This section
designs it so that the day comes with the answer ready.

**It can be done on both stores.** On Play a pack is a consumable one-time
product; on Paddle a one-time product. Play's fee on one-time products is
assumed to be 15% (the first-million tier), as for subscriptions.

**Paddle's fixed $0.50 sets a floor.** On a $1.99 pack the fee would be 30%.
So no pack below $4.99.

| Pack | Contains | Costs us (worst) | Price | Nets (Play) | Margin |
|---|---|---|---|---|---|
| Voice | 1,000 person-minutes (about 17 person-hours) | $0.99 | $4.99 | $3.53 | $2.54 |
| AI | 20 studies, or the same value in tutorial and review words | $1.42 | $4.99 | $3.53 | $2.11 |

Rules a pack would follow:

- the monthly allowance is spent first, the pack after it;
- a pack does not expire at the end of the month — it was paid for;
- a free account may buy one. `PLAN-SKELET.md` D2 already says "premium
  accounts, and free accounts that buy credits". This gives the occasional
  trainer a way to pay without subscribing;
- on Windows the purchase happens on the web, like the subscription.

**What it needs:** a credit ledger on the server, the order of consumption in
`requireQuota`, two products in each store, and a place in `Usage this month`
to see and buy. That is real work, which is the reason to wait for a
subscriber who hits four fifths of an allowance twice.

---

## 4. What an account earns

### What a price nets

VAT of 20% inside the displayed price is **assumed** on both stores.

| Price | Play (15%) | Paddle (5% + $0.50) |
|---|---|---|
| $14.99 a month | $10.62 | $11.37 |
| $149.99 a year (two months free) | $106.24 — $8.85 a month | $118.24 — $9.85 a month |

Play is the worse case, so everything below uses Play.

### Three subscribers at $14.99 a month

| | Light | Typical | Uses everything |
|---|---|---|---|
| Voice | 4 hours one-to-one — $0.48 | 12 hours one-to-one — $1.43 | the allowance — $1.98 |
| AI, films, recordings | $0.17 | $0.54 | $3.25 |
| **Cost** | **$0.65** | **$1.97** | **$5.23** |
| **Left of $10.62** | **$9.97** | **$8.65** | **$5.39** |

The light and typical rows use expected prices and are **assumed** usage —
nobody but the owner has used the app. The third row is the worst case of §2.

Three notes:

- **The yearly plan breaks decision 5's rule in the worst case**: it nets
  $8.85 a month, half of which is $4.43, below $5.23. It still leaves $3.62.
  Any real yearly discount does: the rule needs $10.46 a month, and the
  monthly plan nets $10.62. So a yearly plan means accepting a thinner worst
  case in exchange for cash paid up front.
- **The free tiers of Agora and Azure cover the start.** 10,000 voice minutes
  is five subscribers at the full allowance; 500,000 characters is over a
  hundred median films. The early margin is better than the table.
- **Group trainers do not fit the allowance.** Five students for four hours a
  week is about 96 person-hours a month, three times 33. They are the first
  buyers of the voice pack, or the reason for a larger tier later.

### Break-even

The droplet costs **$30 a month** (the owner, 3.10.2026: 2 GB of memory, one
AMD vCPU, a 50 GB disk). Whether the managed database and the domain are
inside that figure was not said; if they are billed on top, add them. With a
typical margin of $8.65:

> subscribers to cover fixed costs = fixed monthly cost ÷ 8.65

For $30 that is 3.5 — **four subscribers**; each further $8.65 of fixed cost
is one more.

**The disk is the first ceiling, before any bill.** Kept recordings are the
one thing that accumulates: 1.15 GB for a Premium account at its full ten
hours, 58 MB for a free one at its thirty minutes. How much of the 50 GB is
free on the droplet was not measured; if 30 GB are, that is 26 Premium
accounts at the full allowance. Past that the choice is a larger disk or
compressed sound (§1). One vCPU also renders one film at a time — a limit on
how many exports can run in an hour, not a cost, and not measured either.

### What a subscriber is worth over time

Lifetime value is margin divided by monthly churn. Churn is **assumed**; the
only benchmark found says 40–60% of cancellations fall in the first 90 days.

| Monthly churn | Average lifetime | Value at $8.65 a month |
|---|---|---|
| 8% | 12.5 months | $108 |
| 15% | 6.7 months | $58 |

A common rule is to spend at most a third of that to win the customer: **$19
to $36 per paying trainer.** That number governs §5 and §6.

---

## 5. Acquisition: who, and why ads for installs do not pay

**The paying unit is a trainer.** A student costs nothing to win — the trainer
brings them — and pays nothing. So the question is never "what does an install
cost" but "what does a trainer who subscribes cost".

Run the arithmetic for a broad install campaign:

- an Android install in Europe costs somewhere between $0.66 (a general
  benchmark) and $1.80–4.50 (Google App campaigns, non-gaming, US);
- most people who install a chess app are players, not trainers;
- freemium products convert about 3.7% of users to paid on average.

At $1 an install and 1% of installs becoming paying trainers, a subscriber
costs $100 — three to five times the ceiling. Broad install advertising loses
money at this price with one tier. Advertising pays only where the audience is
already trainers, or where the cost is the owner's time instead of money.

### Three constraints before any channel

1. **The country list comes first.** The parent-consent wording is approved
   for Serbia only. An ad shown where the app cannot lawfully take a minor's
   account is money spent on a refusal.
2. **Ads address adults only** — trainers and parents. Never minors, in
   targeting or in wording. The major ad platforms restrict targeting under
   18 in any case.
3. **Nothing can be measured yet.** The app has no install attribution. Adding
   an advertising SDK changes the privacy policy and touches accounts of
   minors. The cheap alternative: one link per channel to the site, and an
   optional "how did you hear about us" at sign-up, counted on the server.

### The measure

One number per channel: **cost per trainer who held a session with at least
one student.** That is the moment the app has done what it is for; installs
and sign-ups are steps on the way.

---

## 6. Channels

### Free, and first

| Channel | Why | Note |
|---|---|---|
| **The app's own films** | A free account's exported film can end on a card naming the app; Premium removes it. Every film a trainer sends or posts is then an advertisement that cost nothing | needs a decision and a small change to the film (§9) |
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
   pricing page (Paddle needs it too).
2. Channel links and the sign-up question, so every later step can be counted.
3. The free channels, for a month. They answer the two unknowns that decide
   everything else: how many trainers who try the app hold a session, and how
   many of those subscribe.
4. Paid tests in the order above, one at a time, each against the ceiling of
   §4.

---

## 7. What the study recommends

- **Price:** $14.99 a month and a yearly plan, with the Premium allowances of
  §2. Voice at 2,000 person-minutes is the tightest line and the one to
  reconsider first.
- **Free tier:** as in §2; watch cost per free account from the first month.
- **Top-ups:** designed (§3), built when a subscriber first needs one.
- **Acquisition:** trainers only; free channels first; the film end card;
  paid tests small and in order, never before attribution exists.
- **Before any of it:** set `USAGE_UNIT_COSTS` from invoices, and give
  translation, transcription and voice a limit — today they have none.

---

## 8. What is assumed, and what would replace it

| Assumption | Replace with |
|---|---|
| A study's tokens all billed as output | the first DeepSeek invoice, or the input/output split from the API's answer |
| Review and translation tokens equal a tutorial's | `ai_review_tokens`, `ai_translation_tokens` after a few real runs |
| 900 narration characters a minute | `tts_azure_characters` against the lengths of the films made |
| Azure and Groq list prices | their pages or an invoice |
| $0.10 per GB-month of storage — the droplet's 50 GB disk is already paid for, so this is the price of space past it | the free space on the droplet, and the provider's price for a volume |
| 20% VAT inside the price on both stores | the first Play payout report; Paddle's documentation |
| Play's 15% on one-time products | Play Console |
| Light and typical usage | the first month with real subscribers |
| Churn of 8–15% a month | three months of subscriptions |
| Fixed costs beyond the droplet's $30 — the managed database, the domain | the owner's invoices |
| Install costs and conversion rates | the free channels' first month |

---

## 9. Decisions this leaves for the owner

1. The price and the yearly discount (§4).
2. The Premium and free allowances (§2) — voice above all.
3. Whether the free tier's limit of 5 homework sends stays, though it costs
   nothing.
4. Whether a free account's film ends on a card naming the app (§6).
5. Whether a free account may buy a pack (§3).
6. The country list — which also bounds where anything is advertised.
7. Whether to accept an advertising SDK in the app, or measure by links and a
   question only (§5).

---

## Sources

Read 3.10.2026.

- Agora voice pricing — <https://www.agora.io/en/pricing/voice-calling>
- DeepSeek models and pricing — <https://api-docs.deepseek.com/quick_start/pricing>
- Google Play service fees — <https://support.google.com/googleplay/android-developer/answer/112622>
- Paddle fees, third-party summary — <https://dodopayments.com/blogs/paddle-fees-explained>
- Install cost benchmarks — <https://www.adjust.com/blog/ecpi-benchmarks/>,
  <https://semnexus.com/cpi-benchmarks-app-category-platform-2026/>
- Freemium and trial conversion — <https://userpilot.com/blog/saas-average-conversion-rate>,
  <https://visionary-marketing.co.uk/blog/saas-free-trial-conversion-statistics-2026>
- Reddit ad costs — <https://stackmatix.com/blog/reddit-ads-cost-guide-2026>
- YouTube sponsorship rates — <https://www.collabpals.com/tools/youtube-sponsorship-rate-calculator>
- Microsoft Store Ads availability — <https://ppc.land/microsoft-advertising-expands-in-europe-and-south-africa/>
- Lichess coach count — <https://lichess.org/ublog/KvYjULSR/redirect>
