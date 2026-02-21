# PRD: Dispatch — macOS Menu Bar PR & CI Status Agent

**Version:** 1.1
**Date:** 2026-02-21
**Status:** Draft — Pre-Development
**Owner:** Ali Murat Kuslu

**Changelog v1.1:**
- MVP scope narrowed to GitHub only; GitLab moved to Phase 2
- Added F1.11: PR Comment Viewer (teammate comments, inline review threads, full detail panel)
- Added F1.12: GitHub Copilot Code Review (optional request + Copilot feedback viewer)
- Added notification events N7 (new comment) and N8 (Copilot review ready)
- Updated GraphQL query, data models, UI layout, and file structure accordingly

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Problem Statement](#2-problem-statement)
3. [Goals & Success Metrics](#3-goals--success-metrics)
4. [Target Users / Personas](#4-target-users--personas)
5. [Feature Requirements](#5-feature-requirements)
6. [Technical Architecture](#6-technical-architecture)
7. [UI/UX Requirements](#7-uiux-requirements)
8. [GitHub API Integration](#8-github-api-integration)
9. [Monetization Model](#9-monetization-model)
10. [Freemium Enforcement](#10-freemium-enforcement)
11. [Security Considerations](#11-security-considerations)
12. [Non-Functional Requirements](#12-non-functional-requirements)
13. [Out of Scope (V1)](#13-out-of-scope-v1)
14. [Development Phases & Milestones](#14-development-phases--milestones)

**Appendices**
- [Appendix A: Notification Event Matrix](#appendix-a-notification-event-matrix)
- [Appendix B: API Query Reference](#appendix-b-api-query-reference)
- [Appendix C: File & Directory Structure](#appendix-c-file--directory-structure)

---

## 1. Executive Summary

**Dispatch** is a native macOS menu bar application that surfaces live pull request review status, pending code review requests, CI/CD build health, teammate comments, and GitHub Copilot code review feedback — directly from the macOS menu bar, without requiring a browser tab.

**MVP scope:** GitHub only. GitLab support is planned for Phase 2.

### Core Value Proposition

Developers currently lose hours per week context-switching to GitHub web interfaces or monitoring Slack bots to answer five questions:
- "Is anyone reviewing my PR?"
- "Did the CI build break?"
- "Do I have a pending review to complete?"
- "Did a teammate leave a comment I need to address?"
- "What did Copilot say about my code?"

Dispatch answers all five at a glance and delivers native push notifications within 60 seconds of any status change — with full comment threads readable without opening a browser.

### Technology Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI Framework | AppKit (menu bar/popover host) + SwiftUI (popover content) |
| Notifications | UserNotifications framework (`UNUserNotificationCenter`) |
| Auth / Secrets | Security framework (Keychain Services) |
| Payments | StoreKit 2 |
| Networking | URLSession + NWPathMonitor |
| Persistence | UserDefaults (non-sensitive) + Keychain (tokens) |
| Build | Xcode 15+, Universal Binary (arm64 + x86_64) |
| Min OS | macOS 13.0 Ventura |

### Business Model

- **Free tier**: Monitor 1 repository; all notification types; GitHub account
- **Pro tier**: $10 one-time purchase (StoreKit 2 non-consumable); unlimited repositories; all Phase 2 features
- **No subscription, no server, no telemetry**

### Zero Third-Party Dependencies

Dispatch is built exclusively on Apple frameworks. No CocoaPods, no SPM packages, no crash reporters. This guarantees App Store approval, minimal attack surface, and a tiny binary footprint.

---

## 2. Problem Statement

### The Status-Checking Tax

Modern software development is collaborative and asynchronous. A developer submits a PR and then must repeatedly answer:

1. Has anyone started reviewing it?
2. Has CI finished — did it pass?
3. Are there change requests I need to address?
4. Has it been approved — can I merge?
5. Did a teammate leave an inline comment on a specific line I need to respond to?
6. What feedback did Copilot give on the code I just wrote?

Answering these questions requires opening a browser, navigating to GitHub, and scanning through a PR page. This happens 8–15 times per day per developer. The comment question is especially disruptive — a single inline comment buried in a diff requires a full context switch just to read one sentence.

### Data Points

- Code sits in review for **~5 days on average** (State of DevOps Report)
- **52% of developers** report feeling blocked waiting for PR feedback
- The average developer spends **~4 hours/week** on PR status management overhead
- Slack PR bots generate noise for the whole channel, not just the individuals who care
- Inline review comments are frequently missed because they don't generate strong enough email/notification signals

### The Gap in Existing Solutions

| Solution | Problem |
|---|---|
| GitHub web notifications | Require browser context-switch; comments buried in PR diff view |
| GitHub mobile app | iOS/Android only; not available on macOS as native menu bar agent |
| Slack bots (GitHub for Slack) | Channel-level noise; no per-developer filtering; no comment content |
| Email notifications | High latency; comment content truncated; not actionable from inbox |
| Browser extensions | Browser-dependent; tab fatigue; no native OS notifications |

**No native macOS menu bar app fills this gap.** Dispatch is that app.

---

## 3. Goals & Success Metrics

### Primary Goals

| Goal | Definition of Done |
|---|---|
| Eliminate manual status-checking | User can identify PR status without opening a browser during a full work session |
| Surface comment content natively | User can read and understand a teammate's comment without opening GitHub |
| Sub-60s notification latency | 95th percentile notification delivery within 60 seconds of event |
| Minimal resource footprint | Does not degrade Mac performance; invisible when idle |
| Zero-server architecture | No backend to maintain, no user data stored off-device |

### Quantitative Success Metrics

#### Launch (Month 1)
- 500 downloads from App Store
- App Store rating ≥ 4.5 stars
- Crash-free sessions ≥ 99.5%
- Avg CPU <0.5% idle on Apple Silicon (measured via Instruments)

#### Growth (Month 6)
- 5,000 Monthly Active Users (MAU)
- 500 Pro conversions → $5,000 revenue
- 7-day retention ≥ 60%
- Avg session time <10 seconds (fast glance, not a productivity sink)

#### Technical Health
- Memory (RSS) <30 MB steady state
- Launch-to-popover-visible latency <500ms
- Zero token exfiltration incidents
- App Sandbox + Hardened Runtime compliant

---

## 4. Target Users / Personas

### Persona 1: Alex — The Solo Contributor

**Role:** Mid-level software engineer at a Series B startup
**Team size:** 8 engineers
**Active PRs:** 2–3 at any time
**Pain point:** Keeps a GitHub tab pinned and refreshes it obsessively while waiting for reviews. Also misses inline comments from reviewers buried in diff views.

**Jobs to be done:**
- Know immediately when a reviewer approves or requests changes
- Read a reviewer's comment without opening GitHub
- Know if CI broke on their PR before a teammate notices
- Know when their PR was merged so they can delete the local branch

**Dispatch value:** Menu bar icon shows status dot; tapping a PR shows all comments in a native panel. Alex closes GitHub tabs.

---

### Persona 2: Priya — The Tech Lead

**Role:** Staff engineer + team lead at a fintech company
**Team size:** 14 engineers
**Reviews per day:** 4–6 PRs
**Pain point:** Slack PR bot pings the entire channel. She leaves detailed inline comments on code and wants to know when the author responds.

**Jobs to be done:**
- See all PRs that require her review, ranked by urgency
- Know when a PR author replies to her comment thread
- Optionally use Copilot to pre-screen PRs before her own review

**Dispatch value:** "Your Review Requests" section shows exactly what Priya owes reviews on. Comment threads in the detail panel let her triage without switching to browser.

---

### Persona 3: Jordan — The OSS Maintainer

**Role:** Senior developer who maintains 3 popular open-source libraries
**Repos:** 3 repos, each receiving 5–20 PRs/week
**Pain point:** GitHub's notification inbox is a firehose of 200+ emails/day. Most comments are noise; a few are critical.

**Jobs to be done:**
- Monitor CI health on main branch of each repo continuously
- Know when a community PR gets approved and is ready to merge
- Use Copilot reviews to help triage incoming PRs without reading every diff personally

**Dispatch value:** Pro tier; CI health per repo; Copilot review summary visible in the comment panel helps Jordan quickly assess whether a community PR needs attention.

---

## 5. Feature Requirements

### 5.1 Phase 1 MVP (12 Weeks)

---

#### F1.1 — Account Connection (GitHub)

**Priority:** P0 (blocker for everything else)

**GitHub:**
- OAuth Device Flow (RFC 8628) — user opens a URL on github.com, enters a code, grants scope; no redirect URI needed; works without a backend server
- PAT fallback — user pastes a classic PAT or fine-grained PAT
- Scopes required: `repo`, `read:user`, `notifications`
- Token stored exclusively in Keychain (never UserDefaults)

**UI:**
- Onboarding screen 3: "Connect GitHub Account" button
- Accounts tab in Preferences: shows connected account (username, avatar, revoke button), re-auth CTA on token expiry

**Acceptance criteria:**
- Token round-trip: connect → verify via `GET /user` → display username + avatar
- Invalid/revoked token shows inline error with re-auth CTA
- Revoking from Preferences deletes Keychain entry and clears all cached data

---

#### F1.2 — Repository Management

**Priority:** P0

- Repository picker: searchable list populated from `GET /user/repos?per_page=100&sort=pushed` (GitHub)
- Search is client-side on the loaded result set; "Load more" fetches next page with `?page=N`
- Checkbox selection; selected repos saved to UserDefaults (repo full names, not tokens)
- **Free tier:** maximum 1 repository enforced by `StoreManager.isPro`
- **Pro tier:** unlimited repositories
- Paywall sheet presented when user attempts to add a 2nd repository without Pro

**Acceptance criteria:**
- Picker loads repos within 2 seconds on standard broadband
- Selecting a repo starts polling within the next poll cycle
- Removing a repo immediately removes it from popover and stops polling it

---

#### F1.3 — Pull Request Status Display

**Priority:** P0

Each PR row in the popover displays:
- PR title (truncated at 45 chars, tooltip shows full title)
- Author avatar (32×32pt, circular clip, cached on disk)
- Review status badge: `Awaiting Review` (gray) / `Changes Requested` (orange) / `Approved` (green)
- CI status badge: `Passing` (green) / `Failing` (red) / `Pending` (yellow) / `Skipped` (gray)
- Unread comment count badge (e.g. `💬 3`) — increments since last time user opened the PR detail panel
- Relative timestamp: "2m ago", "1h ago", "3d ago"
- Tap on row → opens `PRDetailSheet` (see F1.11)
- Long-press / secondary click → context menu with "Open in Browser" option

**Grouping:** PRs grouped by repository name as a section header. Sections sorted alphabetically.

**Acceptance criteria:**
- Data refreshes on every poll cycle without full view reload (diff-based updates)
- Unread comment badge clears when the user opens the PR detail panel
- Empty state: "No open pull requests" with a subtle illustration

---

#### F1.4 — Pending Reviews (Review Requests)

**Priority:** P0

- Dedicated section at top of popover: "Your Review Requests"
- Shows PRs where the authenticated user is a requested reviewer
- GitHub: `viewer.pullRequestReviewRequests` via GraphQL
- Each row: repo name chip + PR title + author name + age + unread comment count badge
- Tap row → opens `PRDetailSheet`
- Badge count on menu bar icon reflects total pending review count

**Acceptance criteria:**
- Section hidden when count = 0 (no empty state shown for this section)
- Count updates within 60 seconds of being added/removed as reviewer

---

#### F1.5 — CI Build Health

**Priority:** P1

- "CI Health" section at bottom of popover
- Shows the latest check-suite result on the **default branch** of each monitored repo
- GitHub: `GET /repos/{owner}/{repo}/commits/{branch}/check-suites` (REST fallback) or via GraphQL `defaultBranchRef → checkSuites`
- Each row: repo name + branch name + status badge + last updated time
- Tap → opens CI run URL in browser

**Acceptance criteria:**
- Accurately reflects current default branch CI status
- Updates within 2 poll cycles (≤120 seconds) of a run completing
- Does not surface PR-specific CI runs (only branch-level runs)

---

#### F1.6 — Native Push Notifications

**Priority:** P0

All notifications use `UNUserNotificationCenter`. No APNS server required. Notification permission requested during onboarding (screen 2).

**Event types:**

| ID | Event | Default |
|---|---|---|
| N1 | CI build failed on monitored branch | Enabled |
| N2 | CI build fixed (was failing, now passing) | Enabled |
| N3 | Review requested (you were added as reviewer) | Enabled |
| N4 | PR approved by a reviewer | Enabled |
| N5 | Changes requested on your PR | Enabled |
| N6 | PR merged | Enabled |
| N7 | New comment on your PR (or a PR you reviewed) | Enabled |
| N8 | Copilot review completed on your PR | Enabled (when Copilot feature is on) |

**Notification anatomy:**
- Title: repo name + concise verb phrase
- Body: PR title + first 80 chars of comment body (for N7) or "Copilot has reviewed your PR" (for N8)
- `userInfo`: `{ "prURL": "https://...", "eventType": "N7", "prNumber": 42 }`
- Click action: open `PRDetailSheet` scrolled to the new comment (if app is running) or open PR URL in browser (if app is not running)

**Per-event toggles:** Each event type individually toggled in Preferences > Notifications tab. N8 only visible when Copilot Reviews feature is enabled (Preferences > General > Copilot Reviews).

**Acceptance criteria:**
- Notification appears within 60 seconds of event occurring in GitHub
- Clicking notification opens correct destination
- No duplicate notifications for the same event (state diffing prevents this)
- Notifications respect macOS Focus modes

---

#### F1.7 — Menu Bar Icon

**Priority:** P0

- 18×18pt template PNG (`menubarIconTemplate`) — adapts to light/dark mode automatically
- 6pt colored status dot rendered at bottom-right corner of icon:
  - **Red dot:** at least one CI failure or one "Changes Requested" on your PR
  - **Yellow dot:** pending review requests or unread comments
  - **Green dot:** all clear — no failures, no pending reviews, no unread comments
  - **No dot:** no data yet / first launch / offline

**Icon rendering:** `IconRenderer.swift` draws the dot via Core Graphics into an `NSImage` at render time; cached until state changes.

**Popover trigger:** clicking the menu bar item toggles the popover.

**Acceptance criteria:**
- Icon renders correctly in both light and dark menu bars
- Status dot color updates within one poll cycle of underlying state change
- Icon does not flash or flicker on data refresh

---

#### F1.8 — Polling Engine

**Priority:** P0

- **Timer:** `DispatchSourceTimer` on a dedicated serial queue (`com.dispatch.polling`)
- **Default interval:** 60 seconds
- **Leeway:** 10 seconds (for OS timer coalescing, reduces wake-from-idle overhead)
- **ETag caching:** All GET requests include `If-None-Match: <last-etag>`. On HTTP 304, skip processing. Store ETags in an in-memory dictionary keyed by URL.
- **Rate limit awareness:** Parse `X-RateLimit-Remaining` and `X-RateLimit-Reset` headers. If remaining < 10, skip poll cycle and log warning.
- **Backoff:** On non-200 error responses (4xx, 5xx, network error), apply exponential backoff starting at 2×, max 8× (8 minutes), then reset on next success.
- **Sleep/wake:** Subscribe to `NSWorkspace.didWakeNotification` to trigger an immediate poll after Mac wakes from sleep.
- **Network monitoring:** `NWPathMonitor` — pause polling when offline; resume + immediate poll when connectivity restored.
- **Low Power Mode:** Observe `ProcessInfo.processInfo.isLowPowerModeEnabled` (via notification); increase interval to 120 seconds when active.

**Acceptance criteria:**
- No network requests made when Mac is offline
- ETag reduces unnecessary JSON parsing by ≥70% in steady state
- Polling stops entirely when no repos are monitored
- Single poll cycle completes within 10 seconds on standard broadband (all repos)

---

#### F1.9 — Preferences Panel

**Priority:** P1

Four tabs implemented in SwiftUI, hosted in a standard `NSWindow` (not a sheet):

**General Tab:**
- Launch at login toggle (`SMAppService.mainApp`)
- Poll interval selector: 30s / 60s (default) / 2min / 5min
- Open popover on launch toggle
- **Copilot Reviews toggle** — master on/off for the Copilot review request feature (F1.12); off by default

**Notifications Tab:**
- Master notifications toggle
- Per-event toggles (N1–N8; N8 only visible when Copilot Reviews is enabled)
- "Send Test Notification" button

**Accounts Tab:**
- Connected GitHub account (username, avatar, revoke button)
- "Connect GitHub Account" button (shown when no account connected)
- Token health indicator: green checkmark (valid) / red warning (expired/invalid)

**Repositories Tab:**
- List of monitored repos with remove (×) button
- "Add Repository..." button → opens repo picker sheet
- Pro badge shown next to count when unlimited repos enabled
- Free tier: shows "1/1 repositories — Upgrade to Pro for unlimited"

**Acceptance criteria:**
- Preferences window opens in <200ms
- Changes persist immediately to UserDefaults
- Closing and reopening Preferences shows last state
- Poll interval change takes effect on the next scheduled cycle

---

#### F1.10 — StoreKit 2 Paywall

**Priority:** P1

**Product ID:** `com.dispatch.pro`
**Type:** Non-consumable one-time purchase
**Price:** $10.00 USD

**Paywall trigger:** user attempts to add a 2nd repository in the free tier.

**Paywall sheet content:**
- App icon + "Dispatch Pro" headline
- Three feature bullets: "Unlimited repositories", "Draft PR filtering (coming soon)", "Priority support"
- Price label (localized, fetched from StoreKit)
- "Get Pro" button → `product.purchase()`
- "Restore Purchases" link → `AppStore.sync()`
- "Maybe Later" dismisses sheet

**Entitlement check:** `StoreManager.isPro` computed by iterating `Transaction.currentEntitlements` on app launch and after each transaction update.

**Acceptance criteria:**
- Product loads price in <2 seconds from App Store
- Purchase flow works end-to-end in StoreKit sandbox
- Restore Purchases works for reinstalls
- `isPro` correctly reflects entitlement after kill + relaunch

---

#### F1.11 — PR Comment Viewer

**Priority:** P1

The PR Comment Viewer gives users the ability to read all discussion on a pull request — general comments, review summaries, and inline code thread comments — inside a native macOS panel, without opening a browser.

##### Triggering the Detail Panel

Tapping any PR row (in "Your Review Requests" or "Open Pull Requests") opens `PRDetailSheet` as an `NSPanel` attached below the popover (or as a `.sheet` on the popover's SwiftUI hierarchy). The panel stays open until dismissed; the popover can remain open behind it.

##### Comment Types Shown

GitHub PRs have three distinct comment types, all of which are displayed:

| Type | GitHub API Source | Display Label |
|---|---|---|
| **General PR comment** | `pullRequest.comments` (issue comments on the PR thread) | No special label |
| **Review summary comment** | `pullRequest.reviews.body` (the top-level comment submitted with a review) | Badge showing review state: `Approved`, `Changes Requested`, or `Commented` |
| **Inline code thread comment** | `pullRequest.reviewThreads.comments` (comments on specific lines of a diff) | File path + line number shown above comment; indented replies shown as thread |

##### Comment Detail Panel Layout

```
┌────────────────────────────────────────────────────────┐
│  ← Back    acme/web  ·  #42 Fix memory leak    [↗ GH]  │  ← navigation bar
├────────────────────────────────────────────────────────┤
│  ✅ Approved by priya  ·  2h ago                        │  ← review summary row
│  ┌────────────────────────────────────────────────────┐ │
│  │ [avatar] priya · 2h ago                            │ │  ← review body comment
│  │  "Looks good overall. Left a few inline notes."   │ │
│  └────────────────────────────────────────────────────┘ │
│                                                        │
│  💬 src/cache/memory.swift · line 47                   │  ← inline thread header
│  ┌────────────────────────────────────────────────────┐ │
│  │ [avatar] priya · 2h ago                            │ │  ← thread comment
│  │  "This will leak if the caller throws. Consider    │ │
│  │   wrapping in a defer block."                      │ │
│  │                                                    │ │
│  │ [avatar] you · 1h ago                              │ │  ← reply in thread
│  │  "Good catch, will fix."                           │ │
│  └────────────────────────────────────────────────────┘ │
│                                                        │
│  💬 src/cache/memory.swift · line 83                   │
│  ┌────────────────────────────────────────────────────┐ │
│  │ [avatar] jordan · 3h ago                           │ │
│  │  "Nit: prefer `capacity` over `count` here."      │ │
│  └────────────────────────────────────────────────────┘ │
│                                                        │
│  🤖 Copilot Review · 45m ago          [See full →]    │  ← Copilot section (if present)
└────────────────────────────────────────────────────────┘
```

##### Panel Specifications

| Property | Value |
|---|---|
| Width | 480pt (fixed) |
| Height | Up to 640pt, scrollable |
| Panel style | `NSPanel` with `.titled`, `.closable`; floating above popover |
| Comment body rendering | Plain text; URLs rendered as tappable links; no full Markdown render in V1 |
| Code snippet context | Not shown in V1 (diff view is out of scope); file path + line number shown as label only |
| Avatar | 24×24pt, circular clip; reuses avatar cache from PR rows |
| Timestamp | Relative ("2h ago"); absolute on hover via tooltip |
| Thread indentation | Reply comments indented 16pt with a left-border accent |

##### Data Fetching

Comments are fetched in the same GraphQL poll cycle as PR status. They are **not** fetched on-demand when the panel opens; the last-polled data is shown instantly. A "Refresh" button in the panel header triggers an immediate on-demand fetch for that specific PR's comments only.

```graphql
# Added to the existing DispatchPoll query (per PR node):
comments(first: 30, orderBy: {field: UPDATED_AT, direction: ASC}) {
  nodes {
    id
    body
    author { login avatarUrl }
    createdAt
    updatedAt
  }
}
reviews(last: 20) {
  nodes {
    id
    state       # APPROVED | CHANGES_REQUESTED | COMMENTED | DISMISSED
    body
    author { login avatarUrl __typename }
    submittedAt
    comments(first: 20) {
      nodes {
        id
        body
        path
        line
        outdated
        author { login avatarUrl }
        createdAt
      }
    }
  }
}
reviewThreads(first: 30) {
  nodes {
    id
    path
    line
    isResolved
    comments(first: 10) {
      nodes {
        id
        body
        author { login avatarUrl __typename }
        createdAt
        replyTo { id }
      }
    }
  }
}
```

##### Unread State Tracking

- `DataStore` records the `updatedAt` timestamp of the most recent comment seen per PR, keyed by PR node ID, stored in `UserDefaults`
- "Unread" = any comment with `createdAt > lastSeenAt[prID]`
- Unread count badge on PR rows reflects this count
- Opening `PRDetailSheet` sets `lastSeenAt[prID] = now`, clearing the badge
- Badges update immediately in the popover without a poll cycle

##### Acceptance Criteria

- All three comment types displayed in a single scrollable list, ordered by time
- Review summary comment shown with correct state badge
- Inline thread comments grouped under their file path + line label
- Replied-to comments shown with correct indentation (thread structure)
- Resolved threads shown in a collapsed/muted state with "Resolved" label
- Copilot review comments distinguished by bot badge (see F1.12)
- Unread badge count accurate and clears on panel open
- Panel shows loading skeleton while on-demand refresh is in progress
- "Open in Browser" button opens the PR's correct GitHub URL

---

#### F1.12 — GitHub Copilot Code Review (Optional)

**Priority:** P1 (optional feature, off by default)

GitHub Copilot can review pull requests and leave inline comments and a summary, just like a human reviewer. Dispatch exposes this capability natively: the user can trigger a Copilot review from the app and then read Copilot's feedback in the PR Comment Viewer.

##### Enabling the Feature

- Toggle in Preferences > General: "Enable GitHub Copilot Reviews" (off by default)
- When enabled, a "Request Copilot Review" button appears on each PR row where the authenticated user is the PR author and no Copilot review has been requested yet
- The toggle requires the user's GitHub account to have Copilot access; if not, an inline error explains this

##### Requesting a Copilot Review

Tapping "Request Copilot Review" on a PR row:

1. Sends a GitHub REST API request to add Copilot as a reviewer:
   ```
   POST /repos/{owner}/{repo}/pulls/{pull_number}/requested_reviewers
   Body: { "reviewers": ["Copilot"] }
   ```
   > **Note:** The exact bot login identifier for GitHub Copilot code review (`"Copilot"` or the registered app slug) should be verified against the GitHub API at implementation time, as GitHub may update this. The request is made on behalf of the authenticated user using their stored token.

2. The button changes to a spinner with "Copilot reviewing…" label
3. On API error (e.g., Copilot not enabled for the repo/org), show an inline error toast: "Copilot code review is not enabled for this repository."
4. On success, the button is hidden and replaced with "Copilot review requested"

##### How Copilot Reviews Appear

Copilot posts its review like any human reviewer: as a GitHub review object with a summary body and inline review comments. These are fetched via the same GraphQL query used for F1.11.

Copilot-authored nodes are identified by:
- `author.__typename == "Bot"` AND `author.login` contains `"copilot"` (case-insensitive)

In the PR Comment Viewer:
- Copilot's review summary appears with a `🤖 Copilot` badge instead of a human avatar
- Copilot's inline comments appear in review threads exactly like human inline comments, but with the `🤖` badge on the author line
- A dedicated **"Copilot Review" section** is pinned at the top of the comment panel (below the PR header) when a Copilot review exists, showing:
  - Overall verdict (Approved / Changes Requested / Commented)
  - Summary body text (Copilot's high-level feedback)
  - Count of inline comments ("12 inline comments — scroll to see them")
  - A "See in GitHub" link

##### Copilot Review Section Layout

```
┌────────────────────────────────────────────────────────┐
│  ← Back    acme/web  ·  #42 Fix memory leak    [↗ GH]  │
├────────────────────────────────────────────────────────┤
│  🤖 COPILOT REVIEW  ·  Changes Requested  ·  45m ago   │  ← Copilot banner
│  ┌────────────────────────────────────────────────────┐ │
│  │ "I found 3 potential issues with this change:      │ │
│  │  memory management in the cache layer, a missing   │ │
│  │  nil check on line 83, and a naming inconsistency. │ │
│  │  See inline comments for details."                 │ │
│  │                                         12 inline ↓│ │
│  └────────────────────────────────────────────────────┘ │
├────────────────────────────────────────────────────────┤
│  (human review comments follow below...)               │
└────────────────────────────────────────────────────────┘
```

##### Notification

When Copilot finishes its review, the polling engine detects the new review object from a bot author. This fires notification N8:
- **Title:** `🤖 Copilot Review Ready`
- **Body:** `{repoName} #{prNumber}: {first 80 chars of Copilot summary}`
- Clicking notification opens `PRDetailSheet` scrolled to the Copilot section

##### Acceptance Criteria

- "Request Copilot Review" button only appears when:
  - Copilot Reviews feature is toggled on in Preferences
  - User is the PR author
  - No Copilot review has been requested yet for this PR
- API call uses the stored token; no additional auth step
- Copilot review comments correctly identified and badged in the comment panel
- Copilot section appears above human reviews in the detail panel when a Copilot review exists
- N8 notification fires within 60 seconds of Copilot submitting its review
- Feature-disabled state (Copilot Reviews toggle off): no buttons shown, no N8 notifications, Copilot comments still rendered in detail panel as regular bot comments

---

### 5.2 Phase 2 (Months 4–7 Post-Launch)

These features are **out of scope for the 12-week MVP** but are planned:

| ID | Feature | Notes |
|---|---|---|
| P2.1 | **GitLab support** | PAT auth; MR viewer; CI health; review requests; comment viewer |
| P2.2 | GitHub Enterprise Server | Custom base URL in Preferences |
| P2.3 | GitLab Self-Managed | Custom GitLab URL support (requires P2.1) |
| P2.4 | Draft PR filtering | Toggle: hide draft PRs in popover |
| P2.5 | Merge conflict detection | Surface `mergeable: CONFLICTING` state |
| P2.6 | Global keyboard shortcut | Configurable hotkey to toggle popover |
| P2.7 | WidgetKit widget | Small/medium widget for macOS desktop |
| P2.8 | Opt-in crash reporting | Local crash log export (no remote SDK) |
| P2.9 | Comment reply from app | Type and post replies to PR comment threads |

---

## 6. Technical Architecture

### 6.1 Component Overview

```
┌─────────────────────────────────────────────────────────────┐
│ macOS Process (LSUIElement = YES, no Dock icon)             │
│                                                             │
│  AppDelegate                                                │
│      │                                                      │
│      ├─▶ StatusBarManager ──▶ NSStatusItem (menu bar)       │
│      │       ├─────────────▶ NSPopover (SwiftUI content)   │
│      │       └─────────────▶ PRDetailPanel (NSPanel)       │
│      │                                                      │
│      ├─▶ DataStore (@MainActor ObservableObject)            │
│      │       ├── [MonitoredRepo]                            │
│      │       ├── [PullRequest]                              │
│      │       ├── [ReviewRequest]                            │
│      │       ├── [PRComment]                                │
│      │       ├── [ReviewThread]                             │
│      │       └── [CIRun]                                    │
│      │                                                      │
│      ├─▶ PollingEngine (DispatchSourceTimer)                │
│      │       └── GitHubAPIClient (URLSession + GraphQL)     │
│      │                                                      │
│      ├─▶ NotificationManager (UNUserNotificationCenter)     │
│      ├─▶ KeychainService (Security framework)              │
│      └─▶ StoreManager (StoreKit 2)                          │
└─────────────────────────────────────────────────────────────┘
```

### 6.2 Data Flow

```
Poll Cycle (every 60s):
PollingEngine
  → GitHubAPIClient.fetchAll(repos:)  → [GitHubPRData + comments + threads]
  → DataStore.merge(newData:)          ← diff old vs new
      → NotificationManager.notify(for: diffResult)
      → StatusBarManager.updateIcon(state: dataStore.overallState)
      → PRDetailPanel.refresh() if open

On-demand (user taps "Refresh" in detail panel):
GitHubAPIClient.fetchPRDetail(pr:)  → comments + threads for one PR
DataStore.mergeComments(for: prID, newData:)
```

### 6.3 Module Responsibilities

| Module | Responsibility |
|---|---|
| `AppDelegate` | App lifecycle; initializes all services; registers for sleep/wake |
| `StatusBarManager` | Owns `NSStatusItem`; renders menu bar icon; manages `NSPopover` + `PRDetailPanel` lifecycle |
| `DataStore` | `@MainActor` `ObservableObject`; single source of truth for UI; publishes diffs; tracks unread comment state |
| `PollingEngine` | Timer management; orchestrates API calls; handles backoff and ETag caching |
| `GitHubAPIClient` | GitHub GraphQL batched queries + REST fallbacks; Copilot review request POST; header parsing |
| `CommentThreadBuilder` | Takes raw `[PRComment]` + `[ReviewThread]` from API and assembles them into a display-ready ordered list |
| `KeychainService` | CRUD for tokens; wraps Security framework with typed Swift API |
| `NotificationManager` | Wraps `UNUserNotificationCenter`; deduplicates; handles click actions |
| `StoreManager` | Product loading; purchase flow; entitlement verification |
| `IconRenderer` | Core Graphics rendering of status dot onto template image |

### 6.4 State Diffing

`DataStore.merge(newData:)` computes the delta between the previous snapshot and the new API data:

```swift
struct DataDiff {
    let newFailingCI: [CIRun]
    let fixedCI: [CIRun]
    let newReviewRequests: [ReviewRequest]
    let newApprovals: [PullRequest]
    let newChangesRequested: [PullRequest]
    let mergedPRs: [PullRequest]
    let newComments: [PRComment]          // general + review body comments
    let newThreadComments: [ThreadComment] // new replies in review threads
    let newCopilotReviews: [PRReview]     // Copilot-authored review objects
}
```

`NotificationManager` receives the diff and fires exactly one notification per new event, preventing duplicates across poll cycles.

### 6.5 Comment Data Models

```swift
struct PRComment: Identifiable, Codable {
    let id: String            // GitHub node ID
    let body: String
    let author: PRAuthor
    let createdAt: Date
    let updatedAt: Date
    let prNodeID: String      // parent PR
}

struct PRAuthor: Codable {
    let login: String
    let avatarURL: URL
    let isBot: Bool           // true when __typename == "Bot"
    var isCopilot: Bool { isBot && login.lowercased().contains("copilot") }
}

struct ReviewThread: Identifiable, Codable {
    let id: String
    let path: String          // file path
    let line: Int?            // nil for file-level comments
    let isResolved: Bool
    let comments: [ThreadComment]
    let prNodeID: String
}

struct ThreadComment: Identifiable, Codable {
    let id: String
    let body: String
    let author: PRAuthor
    let createdAt: Date
    let isOutdated: Bool
}

struct PRReview: Identifiable, Codable {
    let id: String
    let state: ReviewState    // .approved | .changesRequested | .commented | .dismissed
    let body: String
    let author: PRAuthor
    let submittedAt: Date
    let inlineComments: [ThreadComment]
}

enum ReviewState: String, Codable {
    case approved = "APPROVED"
    case changesRequested = "CHANGES_REQUESTED"
    case commented = "COMMENTED"
    case dismissed = "DISMISSED"
}
```

### 6.6 Concurrency Model

- All UI updates and `DataStore` mutations run on `@MainActor`
- API calls run on `URLSession`'s delegate queue (background)
- `PollingEngine` timer fires on `com.dispatch.polling` serial `DispatchQueue`
- `async/await` throughout API clients; `actor` isolation for `KeychainService`
- No `DispatchQueue.main.async` sprawl — use `@MainActor` annotations and `Task { @MainActor in ... }`

---

## 7. UI/UX Requirements

### 7.1 Popover Specifications

| Property | Value |
|---|---|
| Width | 360pt (fixed) |
| Min height | 200pt |
| Max height | 520pt (scrollable beyond) |
| Behavior | `.transient` — closes on click outside; stays open when PRDetailPanel is open |
| Animation | Default NSPopover animation |
| Positioning | Relative to `NSStatusItem` button |
| Background | `NSVisualEffectView` with `.sidebar` material |

### 7.2 Popover Layout (Top → Bottom)

```
┌─────────────────────────────────────────────────┐
│ ⊙ Dispatch                          ⚙  [×]       │  ← header bar
├─────────────────────────────────────────────────┤
│ YOUR REVIEW REQUESTS                    2        │  ← section header
│  ◉ frontend/app  Fix login bug · alex · 3h  💬1 │  ← unread badge
│  ◉ api/service   Add rate limiting · kim · 1d   │
├─────────────────────────────────────────────────┤
│ OPEN PULL REQUESTS                              │
│  ── acme/web ──────────────────────────────     │
│  ✓ ● Add dark mode    [Approved] [Passing] 2h   │
│  ◐ ● Refactor auth    [Awaiting] [Pending] 5m 💬3│ ← 3 unread comments
│  ── acme/api ──────────────────────────────     │
│  ✗ ● Fix memory leak  [Changes]  [Failing] 1h   │
├─────────────────────────────────────────────────┤
│ CI HEALTH                                       │
│  acme/web     main  ● Passing  · 12m ago        │
│  acme/api     main  ● Failing  · 5m ago    →    │
└─────────────────────────────────────────────────┘
```

PR rows are tappable; the entire row is a button that opens `PRDetailSheet`. No separate "expand" chevron needed — the tap target is the full row.

### 7.3 PR Detail Panel

`PRDetailPanel` is an `NSPanel` that opens to the right of or below the popover. It is not a sheet inside the popover (to allow both to be visible simultaneously).

```
┌────────────────────────────────────────────────────────┐
│  ← Back    acme/web  ·  #42 Fix memory leak    [↗ GH]  │
│  priya · 2h ago · [Approved] [Failing CI]  [↻ Refresh] │
├────────────────────────────────────────────────────────┤
│  🤖 COPILOT  Changes Requested  ·  45m ago              │  (shown when present)
│  ┌──────────────────────────────────────────────────┐  │
│  │ "Found 3 issues: memory management, nil check,  │  │
│  │  naming inconsistency. See inline comments."    │  │
│  │                                     12 inline ↓ │  │
│  └──────────────────────────────────────────────────┘  │
├────────────────────────────────────────────────────────┤
│  COMMENTS (4)                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │ [av] priya  ·  2h ago                            │  │
│  │ "Looks good overall. Left a few notes inline."  │  │
│  │ ── Approved ──────────────────────────────────   │  │
│  └──────────────────────────────────────────────────┘  │
│  💬 src/cache/memory.swift · line 47                   │
│  ┌──────────────────────────────────────────────────┐  │
│  │ [av] priya  ·  2h ago                            │  │
│  │ "This will leak if the caller throws..."         │  │
│  │   [av] you  ·  1h ago                            │  │  ← reply, indented
│  │   "Good catch, fixing."                          │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

**Panel specifications:**

| Property | Value |
|---|---|
| Width | 480pt (fixed) |
| Height | Up to 640pt, scrollable |
| Positioning | Opens to the right of the popover if screen space allows; otherwise below |
| Background | `NSVisualEffectView` with `.hudWindow` material |
| Comment body | Plain text; URLs tappable via `AttributedString`; no full Markdown render in V1 |
| Resolved threads | Shown collapsed; tappable to expand |

### 7.4 Menu Bar Icon

- Template image: 18×18pt PDF vector asset named `menubarIconTemplate` in `Assets.xcassets`
- Status dot: 6pt diameter, rendered via Core Graphics, positioned at bottom-right (x:12, y:0)
- Dot colors: `NSColor.systemRed`, `.systemYellow`, `.systemGreen`
- Re-render triggered by `DataStore.$overallState` publisher

### 7.5 Onboarding Flow (5 Screens)

**Screen 1 — Welcome**
- App icon (128pt)
- Headline: "Meet Dispatch"
- Subtitle: "Your pull requests, comments, and CI — always in reach."
- CTA: "Get Started →"

**Screen 2 — Notifications**
- SF Symbol: `bell.badge`
- Headline: "Stay in the loop"
- Body: "Get notified when reviews arrive, CI fails, or teammates leave comments."
- CTA: "Enable Notifications" → calls `UNUserNotificationCenter.requestAuthorization`
- Skip link for users who decline

**Screen 3 — Connect GitHub**
- One large button: "Connect GitHub Account"
- Triggers GitHub OAuth Device Flow (F1.1)
- Success: button turns green with GitHub username displayed
- CTA: "Continue →" (enabled after account connected)

**Screen 4 — Pick a Repository**
- Searchable list of repos from the connected GitHub account
- Subtitle: "Free plan: 1 repository. Upgrade anytime for unlimited."
- Single-select enforced for free tier
- CTA: "Start Watching →"

**Screen 5 — Done**
- SF Symbol: `checkmark.circle.fill` (green)
- Headline: "You're all set!"
- Body: "Dispatch is now watching your repo. Tap any PR to read comments without opening GitHub."
- CTA: "Open Dispatch →" → closes onboarding, opens popover

### 7.6 Loading States

All data rows use `.redacted(reason: .placeholder)` on SwiftUI views during initial load. Fixed skeleton heights:
- PR row: 52pt
- CI row: 40pt
- Review request row: 48pt
- Comment row in detail panel: 64pt (two-line placeholder)

### 7.7 Empty States

| State | Message | CTA |
|---|---|---|
| No repos monitored | "Add a repository to get started" | "Add Repository" button |
| No open PRs | "No open pull requests" | None |
| No comments on PR | "No comments yet" | None |
| Offline | "Offline — last updated 5m ago" | None |
| Auth expired | "GitHub token expired" | "Re-connect" button |
| Copilot not enabled | "Copilot code review is not enabled for this repository" | None (toast, auto-dismisses) |

### 7.8 Accessibility

- All interactive elements: `accessibilityLabel` + `accessibilityHint`
- VoiceOver reading order matches visual layout (top → bottom)
- Status badges read as: "CI status: Failing", "Review: Approved"
- Comment panel: each comment reads as "Author, time ago, comment body"
- Keyboard navigation supported in Preferences window and PR detail panel
- Dynamic Type: Preferences window and detail panel respect system font size

---

## 8. GitHub API Integration

### 8.1 GitHub GraphQL — Primary Poll Query

Single batched query per repo per poll cycle. Fetches PR status, review state, CI status, comments, review threads, and Copilot review data in one round trip.

```graphql
query DispatchPoll($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    pullRequests(first: 20, states: [OPEN], orderBy: {field: UPDATED_AT, direction: DESC}) {
      nodes {
        id
        number
        title
        url
        createdAt
        updatedAt
        isDraft
        author { login avatarUrl }
        mergeable

        reviewRequests(first: 10) {
          nodes {
            requestedReviewer {
              ... on User { login }
            }
          }
        }

        # General PR-level comments (issue comments)
        comments(first: 30, orderBy: {field: UPDATED_AT, direction: ASC}) {
          nodes {
            id
            body
            author { login avatarUrl __typename }
            createdAt
            updatedAt
          }
        }

        # Review objects (each reviewer's submitted review + inline comments)
        reviews(last: 20) {
          nodes {
            id
            state
            body
            author { login avatarUrl __typename }
            submittedAt
            comments(first: 20) {
              nodes {
                id
                body
                path
                line
                outdated
                author { login avatarUrl __typename }
                createdAt
              }
            }
          }
        }

        # Review threads (for grouping inline comments with their context)
        reviewThreads(first: 30) {
          nodes {
            id
            path
            line
            isResolved
            comments(first: 10) {
              nodes {
                id
                body
                author { login avatarUrl __typename }
                createdAt
                replyTo { id }
              }
            }
          }
        }

        # CI status on the PR's head commit
        commits(last: 1) {
          nodes {
            commit {
              statusCheckRollup { state }
              checkSuites(first: 5) {
                nodes { status conclusion app { name } }
              }
            }
          }
        }
      }
    }

    # CI health on default branch
    defaultBranchRef {
      name
      target {
        ... on Commit {
          checkSuites(first: 3) {
            nodes { status conclusion workflowRun { url } }
          }
        }
      }
    }
  }
  viewer { login }
}
```

### 8.2 GitHub REST Endpoints

| Endpoint | Purpose | When Used |
|---|---|---|
| `GET /user` | Verify token + get user info | Auth verification |
| `GET /user/repos?per_page=100&sort=pushed` | Repo picker | Onboarding + Preferences |
| `GET /rate_limit` | Proactive rate limit check | Before heavy polls |
| `GET /repos/{owner}/{repo}/commits/{ref}/check-suites` | CI health fallback | When GraphQL CheckSuites unavailable |
| `POST /repos/{owner}/{repo}/pulls/{pull_number}/requested_reviewers` | Request Copilot review | F1.12 on user tap |

### 8.3 HTTP Request Handling

**ETag caching:**
```swift
// On request construction:
if let etag = etagCache[url] {
    request.setValue(etag, forHTTPHeaderField: "If-None-Match")
}

// On 304 response:
// Skip JSON decoding; return cached data

// On 200 response:
if let newEtag = response.value(forHTTPHeaderField: "ETag") {
    etagCache[url] = newEtag
}
```

**Rate limit handling:**
```swift
let remaining = Int(response.value(forHTTPHeaderField: "X-RateLimit-Remaining") ?? "1000") ?? 1000
let reset = TimeInterval(response.value(forHTTPHeaderField: "X-RateLimit-Reset") ?? "0") ?? 0
if remaining < 10 {
    pollingEngine.pauseUntil(Date(timeIntervalSince1970: reset))
}
```

**Error → Backoff mapping:**

| Response | Action |
|---|---|
| 200 | Reset backoff multiplier to 1× |
| 304 | No action; continue normal polling |
| 401 | Pause polling; surface "Token expired" banner in popover |
| 403 (rate limit) | Pause until `X-RateLimit-Reset` |
| 404 | Remove repo from monitored list; notify user |
| 422/5xx | Apply exponential backoff (2×, 4×, 8×, max 8 min) |
| Network error | Backoff; show offline indicator |

### 8.4 Avatar Caching

- Avatars (user and bot) fetched on first appearance; cached to `NSCachesDirectory/avatars/{login}.png`
- Cache never expires during app session; purged on app restart if >7 days old
- Shown as `AsyncImage` in SwiftUI with `Circle()` clip shape
- Placeholder: `Circle().fill(Color.gray.opacity(0.3))` while loading

### 8.5 Copilot Bot Identity

Copilot review comments are identified in GraphQL responses by:

```swift
// Detection logic in PRAuthor initializer:
let isBot = rawTypename == "Bot"
let isCopilot = isBot && login.lowercased().contains("copilot")
```

The specific bot login string (e.g., `"Copilot"`, `"copilot[bot]"`) must be confirmed against the GitHub API during implementation, as GitHub may update this identifier. The detection should be robust to login variations.

---

## 9. Monetization Model

### 9.1 Pricing

| Tier | Price | Model |
|---|---|---|
| Free | $0 | Permanent; no trial expiry |
| Pro | $10.00 USD | One-time non-consumable purchase |

**Rationale for one-time pricing:**
- Developers distrust subscriptions for utility tools
- $10 is below the "think twice" threshold for developer tools
- No recurring billing support infrastructure needed
- Aligns with zero-server philosophy

### 9.2 Feature Gating

| Feature | Free | Pro |
|---|---|---|
| Repositories | 1 | Unlimited |
| GitHub account | 1 | 1 (unlimited in Phase 2) |
| All notification types (N1–N8) | ✓ | ✓ |
| CI health monitoring | ✓ | ✓ |
| PR comment viewer | ✓ | ✓ |
| Copilot review request | ✓ | ✓ |
| GitLab support | — | ✓ (Phase 2) |
| Draft PR filtering | — | ✓ (Phase 2) |
| Merge conflict detection | — | ✓ (Phase 2) |
| WidgetKit widget | — | ✓ (Phase 2) |
| GitHub Enterprise | — | ✓ (Phase 2) |
| Comment reply from app | — | ✓ (Phase 2) |

### 9.3 StoreKit 2 Implementation

```swift
// Product loading
let products = try await Product.products(for: ["com.dispatch.pro"])
let pro = products.first

// Purchase
let result = try await pro.purchase()
switch result {
case .success(let verification):
    let transaction = try verification.payloadValue
    await transaction.finish()
    await storeManager.refreshEntitlements()
case .userCancelled, .pending:
    break
}

// Entitlement check (called on launch + after Transaction.updates)
for await result in Transaction.currentEntitlements {
    if case .verified(let tx) = result, tx.productID == "com.dispatch.pro" {
        isPro = true
    }
}
```

### 9.4 Restore Purchases

```swift
// Called from "Restore Purchases" button
try await AppStore.sync()
await refreshEntitlements()
```

---

## 10. Freemium Enforcement

### 10.1 Repository Limit

`DataStore.monitoredRepositories` is the authoritative list. `StoreManager.isPro` is checked before any add operation:

```swift
func addRepository(_ repo: MonitoredRepo) throws {
    guard storeManager.isPro || monitoredRepositories.count < 1 else {
        throw DispatchError.proRequired
    }
    monitoredRepositories.append(repo)
    persist()
}
```

### 10.2 Paywall Presentation

Thrown `DispatchError.proRequired` is caught at the UI layer, which presents `PaywallSheet` as a `.sheet(isPresented:)`.

### 10.3 Entitlement Loss Handling

If a user's Pro entitlement is lost (e.g., refund, family sharing revocation):
- Repos beyond the first are marked `paused = true` in `DataStore`
- Polling stops for paused repos
- Popover shows a banner: "Pro subscription ended. Repos paused. [Re-verify Pro]"
- Re-verify calls `AppStore.sync()` and re-checks entitlements
- Paused repos are **never deleted** — they resume polling if Pro is re-established

### 10.4 Reinstall Behavior

On fresh install, `Transaction.currentEntitlements` will return the existing Pro purchase without requiring the user to buy again. "Restore Purchases" button explicitly triggers `AppStore.sync()` as a user-initiated fallback.

---

## 11. Security Considerations

### 11.1 Token Storage

All API tokens are stored exclusively in the macOS Keychain using the Security framework.

```swift
var query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "com.dispatch.app",
    kSecAttrAccount as String: account,
    kSecValueData as String: tokenData,
    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
    kSecUseDataProtectionKeychain as String: true
]
SecItemAdd(query as CFDictionary, nil)
```

**Constraints:**
- `kSecAttrAccessibleAfterFirstUnlock` — tokens available after first device unlock; survives sleep
- `kSecUseDataProtectionKeychain: true` — uses Data Protection encryption (requires App Sandbox)
- Tokens are **never** stored in: `UserDefaults`, `NSCache`, `FileManager` (plain files), or environment variables
- Tokens are **never** logged (even in debug builds — use `OSLog` with `.private` privacy level)

### 11.2 Comment Content Privacy

- Comment body text is held only in `DataStore` in-memory — never written to disk
- Unread tracking stores only the last-seen timestamp per PR node ID (not comment content) in `UserDefaults`
- `PRDetailPanel` renders comment text in-process; no third-party rendering library

### 11.3 Network Security

- All API requests use HTTPS only
- Certificate pinning: not implemented in V1 (App Transport Security handles enforcement)
- `URLSession` configured with default `.ephemeral` session (no credential caching to disk)

### 11.4 App Sandbox + Hardened Runtime

**Entitlements (`Dispatch.entitlements`):**
```xml
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.network.client</key><true/>
<key>com.apple.security.keychain-access-groups</key>
<array><string>$(AppIdentifierPrefix)com.dispatch.app</string></array>
```

```xml
<key>com.apple.security.hardened-runtime</key><true/>
```

### 11.5 Privacy Manifest

`PrivacyInfo.xcprivacy` declares:
- No data collected
- No data linked to identity
- No third-party SDKs
- No use of privacy-sensitive APIs beyond what is declared

### 11.6 Logging

```swift
import OSLog
private let logger = Logger(subsystem: "com.dispatch.app", category: "APIClient")

// Safe:
logger.debug("Fetched \(prs.count) PRs, \(comments.count) comments for \(repoName)")

// Sensitive values redacted on non-developer devices:
logger.debug("Token prefix: \(String(token.prefix(4)), privacy: .private)")
logger.debug("Comment body: \(comment.body, privacy: .private)")
```

---

## 12. Non-Functional Requirements

### 12.1 Performance

| Metric | Target | Measurement Method |
|---|---|---|
| CPU (idle, no active poll) | <0.5% | Instruments → CPU Profiler |
| CPU (during poll cycle) | <5% peak | Instruments |
| Memory (RSS, steady state) | <30 MB | Instruments → Leaks |
| Launch to popover visible | <500ms | `CFAbsoluteTimeGetCurrent()` instrumentation |
| Poll cycle duration | <10 seconds | OSLog timing |
| Notification latency (p95) | <60 seconds | Manual test with stopwatch |
| PRDetailPanel open latency | <100ms | Already in memory; no disk I/O |

**Comment data memory budget:** Up to 20 PRs × 30 comments × avg 200 bytes/comment body = ~120 KB. Well within the 30 MB RSS budget.

### 12.2 Timer Coalescing

```swift
timer.schedule(deadline: .now(), repeating: pollInterval, leeway: .seconds(10))
```

### 12.3 Low Power Mode

```swift
@objc func powerStateChanged() {
    pollingEngine.setInterval(
        ProcessInfo.processInfo.isLowPowerModeEnabled ? 120 : preferences.pollInterval
    )
}
```

### 12.4 Binary & Compatibility

- **Universal Binary:** arm64 + x86_64
- **Minimum deployment target:** macOS 13.0 Ventura
- **Xcode:** 15.0+
- **Swift:** 5.9+

### 12.5 Localization Readiness

All user-facing strings wrapped in `NSLocalizedString` from day 1. Actual translation deferred to post-launch.

### 12.6 Accessibility

- VoiceOver: all controls labeled; comment panel reads comments with author + time + body
- Keyboard navigation: full support in Preferences and `PRDetailPanel`
- Reduced Motion: no animations when `accessibilityDisplayShouldReduceMotion`
- High Contrast: use `NSColor` semantic colors

---

## 13. Out of Scope (V1)

The following are explicitly **not** part of the 12-week MVP:

### Platforms & Services
- **GitLab** (planned Phase 2)
- Azure DevOps / TFS
- Bitbucket
- Jira
- Windows, Linux
- iOS / iPadOS app

### PR Write Actions

Dispatch is read-only in V1:
- Creating pull requests
- **Posting new PR comments or replies** (reading comments is in scope; writing is not)
- Approving or requesting changes via Dispatch UI
- Code diff viewer / inline diff rendering

> Note: Comment text is displayed as plain text only. Markdown is not rendered in V1.

### Infrastructure
- Webhook server / real-time push (polling only in V1)
- APNS — local notifications only
- Remote crash reporting SDK

### UI Features
- Menu bar icon animations / spinning
- Multiple simultaneous `PRDetailPanel` windows (one at a time)
- Drag-and-drop repo reordering

### Integrations
- Slack / email forwarding
- Calendar integration
- Linear / GitHub Projects

---

## 14. Development Phases & Milestones

### Phase 1: MVP (12 Weeks)

| Week(s) | Milestone | Deliverables |
|---|---|---|
| 1–2 | **Project Foundation** | Xcode project, App Sandbox, `AppDelegate` with `LSUIElement`, `StatusBarManager`, hardcoded mock popover with placeholder data |
| 3–4 | **Authentication** | `KeychainService`, GitHub OAuth Device Flow, GitHub PAT fallback, Accounts tab in Preferences |
| 5–6 | **API Clients & Core Models** | `GitHubAPIClient` (GraphQL + REST), `Codable` models for PRs/reviews/CI, `DataStore` populated from live API |
| 7–8 | **Comments & Copilot Models** | Extended GraphQL query with comments + threads, `PRComment`/`ReviewThread`/`PRReview` models, `CommentThreadBuilder`, `DataDiff` with comment fields, `PollingEngine` with ETag/backoff/sleep-wake |
| 9 | **Polling & Core Notifications** | `NotificationManager` with N1–N6 event types, state diffing, menu bar icon status dot |
| 10 | **PR Detail Panel & Comment UI** | `PRDetailPanel` (`NSPanel`), `PRDetailView` (SwiftUI), comment timeline, review thread grouping, Copilot section, unread badge tracking |
| 11 | **Full Popover UI + Notifications N7/N8** | Complete SwiftUI popover, onboarding flow (5 screens), N7/N8 notification events, Copilot review request button + API call, preferences Copilot toggle |
| 12 | **Monetization + Polish** | StoreKit 2, paywall sheet, accessibility audit, `PrivacyInfo.xcprivacy`, App Store screenshots, submission |

### Phase 2: Post-Launch Iteration (Months 4–7)

| Month | Focus |
|---|---|
| 4 | GitLab PAT auth + MR viewer + comment viewer |
| 5 | GitLab CI health + Draft PR filtering + Merge conflict detection |
| 6 | Global keyboard shortcut + WidgetKit widget |
| 7 | Comment reply from app (write support) + GitHub Enterprise |

### Quality Gates (Before Each Milestone)

- [ ] No crashes on main user flows
- [ ] All new code covered by unit tests (models, diffing, Keychain, StoreKit, `CommentThreadBuilder`)
- [ ] No tokens or comment body text logged in OSLog (verified by log review)
- [ ] Instruments: CPU <5% during poll cycle, memory <30 MB
- [ ] App Sandbox validation passes
- [ ] VoiceOver walkthrough completed for new UI

---

## Appendix A: Notification Event Matrix

| ID | Event | Title | Body | Sound |
|---|---|---|---|---|
| N1 | CI build failed | `❌ [RepoName] CI Failed` | `{branch}: {workflowName} failed` | Default |
| N2 | CI build fixed | `✅ [RepoName] CI Fixed` | `{branch}: builds are passing again` | Default |
| N3 | Review requested | `👀 Review Requested` | `{author} wants your review on: {prTitle}` | Default |
| N4 | PR approved | `✅ PR Approved` | `{reviewer} approved: {prTitle}` | Default |
| N5 | Changes requested | `💬 Changes Requested` | `{reviewer} requested changes on: {prTitle}` | Default |
| N6 | PR merged | `🎉 PR Merged` | `{prTitle} was merged` | Default |
| N7 | New comment on your PR | `💬 New Comment` | `{author} on {prTitle}: "{first 80 chars of comment}"` | Default |
| N8 | Copilot review completed | `🤖 Copilot Review Ready` | `{repoName} #{prNumber}: "{first 80 chars of Copilot summary}"` | Default |

**Notes on N7:**
- Fires for new comments on PRs where the authenticated user is either the author or a reviewer
- Does not fire for your own comments (diffing excludes `author.login == viewer.login`)
- Fires for both general PR comments and new review body comments; inline thread replies fire only if the thread was started by the viewer or the PR is authored by the viewer

**Notes on N8:**
- Only fires when the Copilot Reviews feature is enabled in Preferences
- Identified by `author.isCopilot == true` on the new review object in the diff

**Notification deduplication key:** `{eventType}-{repoFullName}-{prNumber}-{actorLogin}-{commentID}`
Stored in an in-memory `Set<String>` that persists across poll cycles; cleared on app relaunch.

---

## Appendix B: API Query Reference

### GitHub GraphQL Rate Limits

- Authenticated: 5,000 points/hour
- Estimated cost per poll cycle with comments (20 PRs, ~30 comments each): ~60–100 points
- At 60s interval: 60 polls/hour × 100 points = 6,000 points/hour — this approaches the limit for large repos
- **Mitigation:** ETag caching means most polls return HTTP 304 with zero GraphQL cost. Actual GraphQL calls only happen when data changed (typically 5–15 polls/hour are cache misses).
- GraphQL cost introspection: use `X-RateLimit-Used` response header; surface a warning in Preferences if approaching limit

### ETag Effectiveness

In steady state (no PR activity), ETags cause the server to return HTTP 304:
- All PR list endpoints
- CI health endpoints
- Comment endpoints (comments on an unchanged PR return 304)

This reduces JSON parsing and GraphQL cost by approximately 80–90% during quiet periods.

### Copilot Review API Note

The `POST /repos/{owner}/{repo}/pulls/{pull_number}/requested_reviewers` endpoint requires:
- A valid user token with `repo` scope (already required for existing features)
- The Copilot code review feature must be enabled for the repository's organization or user account
- The exact `reviewers` value for Copilot should be verified at implementation time (may be `["Copilot"]` or an app slug)

---

## Appendix C: File & Directory Structure

```
Dispatch/
├── Dispatch.xcodeproj/
│   └── project.pbxproj
│
├── Dispatch/
│   ├── App/
│   │   ├── AppDelegate.swift              # NSApplication delegate; service initialization
│   │   ├── Info.plist                     # LSUIElement = YES; NSPrincipalClass
│   │   └── Dispatch.entitlements          # Sandbox + network + keychain entitlements
│   │
│   ├── StatusBar/
│   │   ├── StatusBarManager.swift         # NSStatusItem; NSPopover; PRDetailPanel lifecycle
│   │   └── IconRenderer.swift             # Core Graphics dot rendering onto template image
│   │
│   ├── UI/
│   │   ├── Popover/
│   │   │   ├── PopoverView.swift          # Root SwiftUI view for popover content
│   │   │   ├── PRRowView.swift            # PR row: avatar, title, badges, unread badge
│   │   │   ├── CIRowView.swift            # CI health row per repo
│   │   │   └── PendingReviewRow.swift     # Row in "Your Review Requests" section
│   │   │
│   │   ├── Detail/
│   │   │   ├── PRDetailPanel.swift        # NSPanel host for the PR detail view
│   │   │   ├── PRDetailView.swift         # Root SwiftUI view for detail panel content
│   │   │   ├── CommentRowView.swift       # Single comment (avatar, author, time, body)
│   │   │   ├── ReviewThreadView.swift     # Inline thread: path/line header + indented replies
│   │   │   ├── CopilotReviewSection.swift # Pinned Copilot review banner + summary
│   │   │   └── ReviewSummaryRow.swift     # Review-level row (APPROVED / CHANGES_REQUESTED badge)
│   │   │
│   │   ├── Preferences/
│   │   │   └── PreferencesWindow.swift    # NSWindow host for SwiftUI Preferences tabs
│   │   │
│   │   ├── Paywall/
│   │   │   └── PaywallSheet.swift         # StoreKit 2 paywall presented as sheet
│   │   │
│   │   └── Onboarding/
│   │       ├── OnboardingCoordinator.swift
│   │       ├── WelcomeScreen.swift
│   │       ├── NotificationsScreen.swift
│   │       ├── ConnectAccountScreen.swift  # GitHub OAuth Device Flow UI
│   │       ├── RepoPickerScreen.swift
│   │       └── DoneScreen.swift
│   │
│   ├── Data/
│   │   ├── DataStore.swift                # @MainActor ObservableObject; merge + diff; unread tracking
│   │   ├── Models/
│   │   │   ├── PullRequest.swift          # Codable model + computed properties
│   │   │   ├── ReviewRequest.swift
│   │   │   ├── PRComment.swift            # General PR-level comments
│   │   │   ├── PRReview.swift             # Review object (state + body + inline comments)
│   │   │   ├── ReviewThread.swift         # Inline thread (path + line + replies)
│   │   │   ├── PRAuthor.swift             # Shared author model; isCopilot detection
│   │   │   ├── CIRun.swift
│   │   │   ├── MonitoredRepo.swift
│   │   │   ├── Account.swift
│   │   │   └── DataDiff.swift             # Diff result struct; includes newComments + newCopilotReviews
│   │   └── Persistence/
│   │       └── UserDefaultsStore.swift    # Non-sensitive preferences + unread timestamps
│   │
│   ├── Services/
│   │   ├── PollingEngine.swift            # DispatchSourceTimer; orchestration; backoff
│   │   ├── CommentThreadBuilder.swift     # Assembles display-ordered comment list from raw API data
│   │   ├── NotificationManager.swift      # UNUserNotificationCenter; N1–N8; deduplication
│   │   ├── KeychainService.swift          # Typed Keychain CRUD (actor-isolated)
│   │   └── StoreManager.swift             # StoreKit 2 product load + entitlement check
│   │
│   ├── API/
│   │   ├── GitHubAPIClient.swift          # URLSession + GraphQL + REST; ETag; Copilot POST
│   │   ├── APIError.swift                 # Typed error enum + backoff mapping
│   │   └── Queries/
│   │       └── GitHubGraphQL.swift        # Full poll query string constant (PRs + comments + threads)
│   │
│   └── Resources/
│       ├── Assets.xcassets/
│       │   ├── AppIcon.appiconset/
│       │   └── menubarIconTemplate.imageset/
│       ├── Localizable.strings            # NSLocalizedString keys (en base)
│       └── PrivacyInfo.xcprivacy          # Privacy manifest (required for App Store)
│
└── DispatchTests/
    ├── DataStoreTests.swift               # Diff logic; unread tracking
    ├── CommentThreadBuilderTests.swift    # Thread assembly; Copilot detection; reply ordering
    ├── KeychainServiceTests.swift         # CRUD round-trip
    ├── PollingEngineTests.swift           # Backoff + ETag logic
    ├── GitHubAPIClientTests.swift         # URLSession mock tests
    └── StoreManagerTests.swift           # StoreKit sandbox tests
```

---

*End of PRD — Dispatch v1.1*

*This document is the single source of truth for Phase 1 development. All implementation decisions should trace back to a requirement in this document. If a requirement is missing, update this PRD before writing code.*
