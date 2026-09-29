# Sign-in and Settings on a desktop, and a password that is remembered

Written 29.9.2026. **Decided by the owner the same day: D1 B, everything else
as recommended** (D2 A, D3 Windows Credential Manager, D4 Android unchanged, D5
one password per address, D6 F1–F4 fixed including the badge's deletion). Sketches, drawn at the owner's window
(1536 × 792 logical, 125 % scaling), are in
[`skice/prijava-i-podesavanja/`](skice/prijava-i-podesavanja/): `login-a`,
`login-b`, `login-accounts`, `settings-a`, `settings-b`. They use invented
names and `example.com` addresses because this repository is public.

## 1. The request

The owner, 29.9.2026 (paraphrased from Serbian): *reorganise the Settings screen
and the sign-in screen for Windows; they look like Android screens stretched to
the width of a desktop. And let „Remember me" keep the email and the password,
so that signing in again with email needs no typing.*

## 2. What is there today (read and measured 29.9.2026)

### 2.1 The sign-in screen

`lib/screens/login_screen.dart`: `Scaffold` with an `AppBar` (title „Sign In",
action „Continue as Guest"), then `Center > SingleChildScrollView > Card >
Column`. **Nothing limits the card's width**, so in a 1536 px window every field
and button is about 1400 px wide and the „or" line crosses the screen — the
owner's screenshot of 29.9.2026. Google sits above the email form on purpose
(27.8.2026: under the form it read as „press this one instead").

### 2.2 Settings

`lib/screens/settings_screen.dart` (887 lines), reached only as
`AppRoutes.preferences`, pushed over whatever is open: Home's ⚙, Analysis,
Preparation, the room, and `Ctrl+,`. One `ListView` of full-width cards, in
this order: profile header · APPEARANCE · ACCOUNT (statistics, Usage this
month) · STOCKFISH ENGINE · BOARD AND PANEL APPEARANCE · SPEECH · ACCOUNT
(birth year, parent email) · HELP · KEYBOARD SHORTCUTS · the build line · the
Design Gallery (debug builds only).

Four faults found by reading it. Nobody asked about them; they are listed so
the owner can decide (D6):

- **F1.** „ACCOUNT" is a heading twice.
- **F2.** The header's only control is an icon with a tooltip. For a guest the
  icon and the tooltip say „Log in", and a click opens *„Are you sure you want
  to log out?"*.
- **F3.** A guest's header reads „Gost Korisnik" and „gost@chesstrainers.app"
  (`UserSession.guest()`): Serbian on an English-only screen, and an address
  that belongs to nobody. Nothing else in `lib/`, `test/` or the server reads
  either string.
- **F4.** The „User" badge under the address is a constant. It used to show
  the role, and the role decides nothing now except `admin`.

### 2.3 „Remember me"

Ticked, it keeps the token (7 days) and the address. `SessionService.init()`
restores the session at start. **The password is not kept, on purpose**
(27.8.2026, `arhiva/STANJE-RADA-26.8-do-2.9.2026.md`): `SharedPreferences` is
a plain file on Windows, and most accounts belong to minors. The operating
system's password manager was supposed to do the job instead, through
`autofillHints` and `TextInput.finishAutofillContext()`.

**On Windows that route does not exist.** Measured on the SDK's engine:
`flutter_windows.dll` handles seven `TextInput.*` methods (`clearClient`,
`hide`, `setClient`, `setEditableSizeAndTransform`, `setEditingState`,
`setMarkedTextRect`, `show`). `finishAutofillContext` is not one of them. The
framework translates autofill hints only for Android and iOS
(`services/autofill.dart`), and Windows has no autofill service for desktop
programs. The Android embedding does handle the call
(`TextInputChannel$TextInputMethodHandler` in `flutter.jar`). So Windows never
offered to save the password, and two claims were wrong: the comment at
`login_screen.dart:309` and the archived check that said „on Windows it works
the same". That is why the owner types the password every time on Windows.

The password form comes back, even with the box ticked, when:
- the user signs out,
- the 7 days run out, or the server refuses the token,
- the user switches accounts. The owner does this all the time while testing
  trainer and student side by side.

## 3. Decisions — answered 29.9.2026

The owner: *„sve po preporuci, osim D1: lepša mi je B opcija"* — everything as
recommended, except D1, where B looked better to him. The options are kept
below as they were put to him.

**D1 — the sign-in screen on a wide window.**
- **A (recommended):** one card, at most 880 wide, with the two ways in side
  by side: email on the left, a vertical line with „or", Google on the right.
  „Continue as guest" goes under the card and the bar goes. The width holds
  things the user can act on. Side by side also settles the 27.8 finding
  better than a line between two stacked blocks, because nothing sits above
  the form any more.
- **B:** a brand panel on the left (name, a sentence, a board), today's single
  column on the right, 440 wide. It fills the width with decoration.

**D2 — Settings on a wide window.**
- **A (recommended):** a profile strip across the top, then the sections as
  cards flowing into columns: four at 1536, three at the 900 px minimum
  window, one on a phone. This is the rule the Home and Teach tabs already use
  (`PLAN-POCETNI-TABOVI.md` §3, `AdaptiveCardColumns`). At the owner's window
  everything is on one screen with no scrolling.
- **B:** a list of sections on the left and one section at a time on the
  right, like Windows' own Settings. There is room to grow, but with five
  small sections most of the pane stays empty, and every other setting is a
  click away instead of already on screen.

**D3 — where the password is kept on Windows.**
- **Windows Credential Manager (recommended).** One entry per address, stored
  per Windows user and encrypted by Windows (DPAPI) under that user's sign-in.
  The person can see and remove it in *Control Panel → Credential Manager →
  Windows Credentials*. It is reached through `package:win32`, which is
  already in the build (5.15.0, pulled in by other packages). It becomes a
  direct dependency, with nothing new downloaded. **Never `SharedPreferences`.**
- *Alternative:* `flutter_secure_storage`, which would be a new dependency and
  covers Android too.
- **What it costs, said plainly:**
  - Any program running as the same Windows user can read the entry, just as
    it can read a browser's saved passwords.
  - On a computer shared under one Windows account, anybody at it can sign in
    as the saved account. The kept token already allows that for 7 days.
  - What is new is exposure of the password itself, which its owner may also
    use somewhere else.

**D4 — Android.**
- **Unchanged (recommended).** The phone has its own password manager, and the
  app already talks to it (§2.3). Its „Save password?" is Android's to offer.
  One live check confirms that it does on the owner's phone.
- If it does not, a follow-up phase keeps the password in the Android Keystore.
- The sentence under the checkbox says what happens on each platform.

**D5 — several accounts.**
- **Recommended:** one saved password per address. The email field gets a list
  of remembered addresses (sketch `login-accounts`).
  - Choosing an address fills in its password.
  - Typing an address that has a saved password fills it in too.
  - × forgets the address and its password.
- *Alternative:* only the last address and its password.

**D6 — the four findings in Settings (§2.2).** Recommended, as part of phase 3:
- F1: one Account section.
- F2: a guest sees a labelled „Sign in", which goes to the sign-in screen with
  no question. A signed-in user sees a labelled „Sign out" and today's
  question.
- F3: a guest's header reads „Guest", with no address.
- F4: the badge is deleted. This one is a deletion, so it waits for a yes.

Each of the four reverts in a line.

## 4. The rules this plan builds

### 4.1 The saved password (D3, D5)

- **One home:** `SavedSignIns` (`lib/services/saved_sign_ins.dart`), with
  `addresses()`, `passwordFor(email)`, `save(email, password)` and
  `forget(email)`.
  - The list of remembered addresses stays in `SharedPreferences`, addresses
    only. It generalises today's `last_email`, which is moved into it once, on
    first read.
  - Passwords live only in the platform's store. On Windows that is a generic
    credential named `Mislisha/<address>` with `CRED_PERSIST_LOCAL_MACHINE`:
    this computer and this Windows user, never roaming with a domain profile.
  - On every other platform the store holds no passwords, and `passwordFor`
    answers null.
- **Written only after the server says yes:** a 200 from `/login`, or a
  successful `/verify-email` while the password is still in the form. A wrong
  password is never stored.
- **Forgotten when:**
  - A sign-in succeeds with the box unticked: that address's password and the
    address itself are forgotten, as the address is today.
  - The server refuses a *saved* password: a 400 without
    `requiresVerification`, meaning „Invalid email or password" or „This
    account uses Google sign-in and has no password". The field is emptied and
    a sentence says why.
  - The account is gone: `expire(reason: 'account-gone')` forgets the address
    it ended.
  - The user presses × in the list, or „Forget" in Settings → Account.
- **Kept when:**
  - The user signs out. Keeping it through a sign-out is the point of the
    feature.
  - The failure is a 429 (too many attempts), a 5xx, or no network. „Could
    not reach" is not „wrong" — the third answer (CLAUDE.md rule 11).
- **Do the thing, then say it.** If the store fails to write, the sign-in
  still completes, and a sentence says the password was not saved.
- **Show / hide password** — the owner's request of 29.9.2026, made while
  phase 1 was being built: an eye on the password field, when signing in and
  when registering. **A saved password is never shown**: the eye is greyed
  out while the field holds one, and it stays greyed out after the field is
  edited, until the field has been emptied — otherwise one keystroke would be
  the way to read the rest. Edge does the same for a password it filled. The
  owner was told this rule when it was added; dropping it is one line.
- **One fact behind all of it:** `_filledFrom`, the address whose saved
  password the field was filled with, held until the field is emptied. It
  locks the eye, and it empties the field when the address changes (so a
  saved password — or one grown from it — is never sent with another
  address). Whether the *unchanged* saved password went out is decided at
  the moment of sending, by comparing with the store, so an edited one that
  the server refuses is not forgotten.
- Editing the field changes only what is sent. The saved password is replaced
  only after the new one works.
- **Focus:**
  - Both fields filled from the store: focus goes to „Sign in with email", so
    Enter signs in.
  - Only the address known: focus goes to the password, as today.

### 4.2 The sign-in screen (D1 B)

- **Decided by width, not by platform.** The screen reads the width it is
  given from `LayoutBuilder`, never the window. The panel appears only where
  the form keeps its full 440 beside a panel at least as wide, so from about
  900: the smallest Windows window (900, `win32_window.cpp`) gets it. A phone
  upright (360) and the owner's phone on its side (760 × 360) keep today's
  screen exactly: bar, Google above the line.
- **Wide:** two halves.
  - **Left, the brand panel:** the trophy, „Mislisha", one sentence about
    what the app is for, and a board drawn by the app's own
    `BoardThumbnail` in the chosen skin. Nothing on it can be clicked. It
    takes the brand colour in both themes.
  - **Right, the form:** today's form, unchanged in order (Google above the
    line, then the email form), at most 440 wide, centred in its half, and
    scrolling when the window is short. It has no card around it and no
    bar. „Continue as guest" sits in the half's top-right corner, where the
    bar had it. The heading „Sign in" / „Register" / „Email Verification"
    heads the form.
- **The verification code and a build with no Google client** keep the same
  two halves; only the form's content changes, as it does today.

### 4.3 Settings (D2 A, D6)

- **Profile strip:** avatar, name, address, and a labelled „Sign out" (or
  „Sign in" for a guest), across the full width. The plan chip stays in the
  statistics card, which is where it is fetched.
- **Five sections**, each a heading plus its card, laid out as units by
  `AdaptiveCardColumns`, so the column count comes from
  `AdaptiveCardGrid.columnsFor` and the phone keeps one column by
  construction:
  1. **Account:** statistics, Usage this month, birth year, parent email
     (minors only), and „Saved sign-in on this computer" with Forget (Windows
     only).
  2. **Appearance:** unchanged.
  3. **Board and engine:** coordinates and move animation, then the engine
     note and the local `.exe`. This merges two sections; the 17.9 review
     left each with too little to stand alone.
  4. **Speech:** unchanged.
  5. **Help:** the user manual, keyboard shortcuts and the build line (plus
     the Design Gallery in debug).
- **On a phone** the only change is this order: Account moves up to follow
  the profile, and the merged sections read as described.

## 5. Phases

The baseline (the app's test count, the analyze list, the backend untouched)
is measured in the tree at the start of phase 1, not quoted from here.

| # | Phase | Who | Gate |
|---|---|---|---|
| 1 | **Built 29.9.2026, lead inline** — see §5.1. **The saved password** (§4.1): `SavedSignIns`, its Windows store, the login screen's wiring and address list, the Settings row. The wrong comments at `login_screen.dart:309` and in `session_service.dart` are corrected. | **lead**: it stores a secret, which is never delegated | Against a fake store and a faked HTTP client (`http.runWithClient` + `MockClient`), asserting on the request sent: saved exactly after a 200 with the box ticked, never after a 400; unticked forgets; both fields filled and Enter sends the saved password; choosing another address fills its password, and an address without one empties the field; a refused saved password is forgotten and said, while 429/500/no network keep it; `account-gone` forgets; sign-out keeps; × and Forget forget; **after every case no `SharedPreferences` value equals the password** (every key scanned); a store that throws still signs in and says so; off Windows the checkbox's sentence is today's and nothing is saved. A Windows-only case (`@TestOn('windows')`, own target prefix, removed in tearDown) makes a round trip through the real Credential Manager; CI runs on Ubuntu and skips it, which the file says. Mutations: save before the 200, forget on 429, skip the unticked forget, write to prefs, drop the focus move. `login_screen_test`'s „the password never is" stays as the **non-Windows** case and is rewritten openly for Windows. |
| 2 | **Built 29.9.2026, lead inline** — §5.2. **Sign-in layout** (§4.2, D1 B) | lead (was `[implementer]`) | At 1536 × 792 and 900 × 700: the panel left of the form, read from painted positions; the form ≤ 440 wide and centred in its half; no bar; „Continue as guest" in the form half, and it enters as guest; the panel's board measured square. At 360 × 640 and 760 × 360: today's layout, and the existing 360 case stays. A wide window holding a 600 px box gives **no** panel (decided from the constraint). Verification state and no Google: panel and form, and the form's content as today. The Google label read with `didExceedMaxLines` at 900. No overflow at any of the four sizes. |
| 3 | **Built 29.9.2026, lead inline** — §5.2. **Settings layout** (§4.3, D2 A, D6) | lead (was `[implementer]`) | Columns counted from painted positions: 4 at 1536, 3 at 900, 1 at 360; the sections in reading order; no overflow at 360, 900, 1536 and 1920; board thumbnails measured square at 900 and 1536 on **both** Windows and Android `visualDensity`; „ACCOUNT" found exactly once; a guest's „Sign in" goes to the sign-in route with no dialog; „Sign out" keeps its question; a guest's header holds neither „Gost" nor „@chesstrainers.app"; no „User" badge. Existing: `appearance_settings_test`, `user_manual_link_test`, `usage_screen_test`, `desktop_shortcuts_test`, `navigation_flow_test`, `widget_test`. Deleted headings and labels are grepped in `test/support/` and `site/` too. |
| 4 | **Done 29.9.2026** but for the owner's pass: manual, [253.1]–[253.10]. **Words and the live pass** | lead | The manual (`site/mislisha/manual/getting-started.html` describes „Remember me"; any settings page quoting a merged heading), `manual_labels_test` green, and items [253.1]–[253.x] in `docs/TODO-provera.md`. |

Every brief carries the sentence: *If you believe a test in the gate is wrong,
stop and say so in the report — do not work around it.*

### 5.1 Phase 1, as built

- **Where:** `lib/services/password_store.dart` (the interface, and the
  choice: Windows only, and never inside a test run),
  `windows_credential_store.dart`, `saved_sign_ins.dart` (the one home);
  `session_service.dart` decides keep/forget in `signIn` and `expire`;
  `login_screen.dart` (the list under the address, the eye, the focus);
  `settings_screen.dart` („Saved sign-in on this computer", Windows only).
  `win32` and `ffi` became direct dependencies at the versions already in
  the lock file.
- **Gate:** `saved_sign_ins_test` (15), `login_saved_password_test` (18),
  `settings_saved_sign_in_test` (4), `windows_credential_store_test` (5,
  Windows only), two new cases in `move_tree_semantics_orphan_test` (the
  accounts popup and the eye's tooltip), and `login_screen_test`'s „the
  password never is" rewritten openly as the no-store case.
- **What the real store found on its first run:** a password never kept
  read as an error, „0x00000000: The operation completed successfully".
  `package:win32` looks a function up the first time it is called, and the
  lookup is itself a Windows call that resets the last error — so the first
  `GetLastError` after a failed `CredRead` answered 0. Only the first case
  failed, because by the second the lookup was done. `GetLastError` is now
  resolved before every store call. No fake could have shown it: a store in
  memory has no last error.
- **What reasoning found before the mutation round:** the first version
  unlocked the eye on any edit, so adding one character to a filled-in
  password revealed the rest. Found by asking what the lock was for, not by
  a test; it has its case now.
- **What the render found:** the greyed-out eye was drawn exactly like the
  live one — the field hands its suffix one colour whatever the button's
  state, and the button's own `disabledColor` leaked into its enabled state
  too. The locked eye's icon now carries its own colour (muted, 40 %), and
  the case asserts the drawn alpha of both states.
- **Mutations: 23.** 22 red on the case meant for each. M22 (the Settings
  row's own guest check) survived because the section around it is already
  drawn only for a signed-in account — one fact, two guards — and the inner
  guard was deleted. M23 (a tooltip inside the accounts popup) survived the
  first sweep, which hovered only the closed screen; with the popup open it
  is red, and the failure is two orphaned nodes: **a lone tooltip inside a
  popup is refused by the Windows engine too**, not only the nested shape
  known from 22.9.

### 5.2 Phases 2 and 3, as built (29.9.2026, lead inline)

- **Sign-in (D1 B):** `LoginRegisterScreen.panelFromWidth = 880` and
  `formMaxWidth = 440`, read from the screen's own constraint. Wide: the
  brand panel (the light theme's violet in both themes, white text at
  5.7:1, a `BoardThumbnail` of the start position), the form beside it with
  no card and no bar, „Continue as Guest" in the form half's corner. Narrow:
  the screen as it was. Gate `login_layout_test` (12): halves read from
  painted rectangles at 1536 and 900, the board square, the guest door, the
  Google label measured in Roboto, the phone at 360 and 760 × 360 unchanged,
  a 600 px box in a wide window with no panel, registration without Google.
  Mutations 5, all red — after one survivor: the width check compared the
  form with `formMaxWidth` itself, so it followed the constant to 4400; it
  compares with 440 now.
- **Settings (D2 A, D6):** a profile strip (labelled „Sign out" that asks;
  „Sign in" for a guest that goes straight to the sign-in screen; the
  button under the name below 480 px), then five sections dealt into
  `AdaptiveCardColumns`: Account (one guard for its four signed-in rows),
  Appearance, Board and engine (merged), Speech, Help (manual, shortcuts,
  build line). `UserSession.guest()` is „Guest" with no address — Home's
  „Welcome, Gost Korisnik!" went with it. „Saved sign-in on this computer"
  puts „Forget" under its sentence, because beside it, in a 281 px column,
  the title broke into four one-word lines (seen in the render, not in a
  test). Gate `settings_layout_test` (17): columns counted from painted
  headings (4 / 3 / 1), reading order both ways, no overflow at 360 / 900 /
  1536 / 1920, board choices square under Android and Windows density,
  „ACCOUNT" once, the header's four findings. Mutations 6, all red.
  `usage_screen_test` rewritten openly: its absence check stood under
  „STOCKFISH ENGINE", which merged away; it stands under „APPEARANCE" now.

## 6. Live checks (become [253.x] when built)

1. Windows: sign in with the box ticked, sign out. The address and the dots are
   there; Enter signs in.
2. Windows: the entry is visible in *Credential Manager → Windows Credentials*.
   After Forget in Settings it is gone, and the screen asks for the password.
3. Windows: two accounts. Choosing the other one from the list fills its
   password.
4. Windows: change nothing, but make the saved password wrong (edit the entry
   in Credential Manager). The screen says it was forgotten and empties the
   field.
5. Android (D4): on the first email sign-in the phone offers to save the
   password, and next time it offers to fill it.
6. Sign-in at 1536 and at the smallest window; Settings at the same two sizes;
   the phone, both screens, unchanged but for the Settings order.

## 7. Not in this plan

- No server change. The token's 7 days stay as they are.
- Google sign-in is unchanged.
- macOS and Linux are not targets.
- **Open, for the owner:** the privacy policy says passwords are held as a
  bcrypt hash (§ on the account, and the security section). That is about the
  server, and a password kept on the person's own computer at their own
  choice is not held by us. Whether the lawyer wants one sentence about it is
  the owner's question. The legal texts change only on his word.
