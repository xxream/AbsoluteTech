# Health Analytics & Insights

A cross-platform health analytics app for Android and iOS. It brings a user's
health records into a private, on-device dashboard, then summarizes activity,
sleep, and other supported metrics as trends and evidence-backed insights.

This README is the product brief and delivery plan. The repository is at the
planning/bootstrap stage; dates and store approvals are not commitments.

## Product direction

### Problem and value

Health information is spread across device and companion apps. This app aims to
help users see their own long-term patterns in one place, without uploading
their health records to an app-operated server.

The product will:

- Connect to Android Health Connect and Apple HealthKit through platform-specific
  adapters.
- Cache normalized data locally so the interface can show history without
  repeatedly querying platform stores.
- Present daily summaries, weekly and monthly trends, and comparisons between
  user-selected metrics.
- Generate descriptive insights with the underlying comparison and sample size
  visible to the user.
- Offer optional PDF reports and a paid tier only after core data access and
  privacy behavior are reliable.

### Product principles

1. **User control:** Explain each requested data type, request access only when
   needed, support partial grants, and provide clear disconnect and local-data
   deletion controls.
2. **Local-first:** Health records and derived insights stay on-device. Any
   future account, billing, crash reporting, or analytics service must be
   separately reviewed and must not silently transmit health data.
3. **Evidence over claims:** Correlation is not causation. Show cohort sizes,
   date ranges, missing-data limitations, and the compared values; do not
   present statistical associations as medical advice.
4. **Platform-aware behavior:** Health Connect and HealthKit have different
   permission, history, background-access, and store-review rules. A shared UI
   must not imply identical platform capabilities.
5. **No double counting:** Prefer the platform's supported aggregate queries
   for cumulative metrics. Define source precedence and overlap behavior, then
   verify results against multi-source test data before launch.

## Scope and release boundaries

### Core metrics under evaluation

Steps, sleep sessions and stages, heart rate, exercise sessions, body weight,
and active/total energy. Each platform adapter will expose only metric types
that are supported and permitted on that platform. Unsupported or denied metrics
must remain clearly unavailable rather than being represented as zero.

### Initial product tiers

- **Free:** Connect supported health sources, view daily summaries, and inspect
  basic short-term trends without ads.
- **Pro (later milestone):** Longer-range comparisons, saved insights, and PDF
  reports. Subscription work is gated on validated product value, platform
  billing requirements, and a clear restore/cancel experience.

The app must not make subscription eligibility depend on storing or uploading
health data. Any threshold-based teaser must not expose sensitive details on a
locked screen.

### Explicitly out of scope for the first release

- Diagnosis, treatment recommendations, emergency monitoring, and medical
  claims.
- A cloud health-record backend or cross-device health-data synchronization.
- Guaranteeing access to another provider's records; availability depends on
  what the user and installed source apps have written to the platform store.

## Technical direction

### Cross-platform architecture

Use **Flutter and Dart** for the shared application, since Android and iOS are
both required. Keep platform health access behind typed adapters:

- Android: Health Connect, with version/device availability checks, explicit
  permission rationale, partial grants, and platform-specific history limits.
- iOS: HealthKit, with separate read authorization handling and the expected
  privacy semantics (the app must not infer that a denied read authorization
  means there are no records).
- Shared domain layer: normalized records, local persistence, aggregation,
  trend/insight calculations, and UI state.

Select concrete health, database, chart, PDF, and billing packages during
scaffolding only after checking current maintenance, platform coverage, license,
and API limitations. Keep native bridges replaceable; do not couple product
logic to a plugin's data model.

### Data flow

1. Explain the purpose of each data type and request the minimum permissions for
   the screen or feature the user chooses.
2. Read supported platform records and aggregates through the relevant adapter.
3. Normalize units, timestamps, time zones, source metadata, and record identity.
4. Upsert normalized records and computed daily summaries into local storage.
5. Calculate trends and insights from cached data, with reproducible inputs.
6. Render missing, denied, unavailable, stale, and empty states distinctly.

The local model should include source record identity and provenance, timezone
context, sync cursor/state, daily aggregates, workouts, and generated insight
evidence. Sync must be idempotent and recover from revoked access, deleted source
records, token expiry, and interrupted work. Data retention, export, and deletion
behavior must be documented and tested.

### Insight guardrails

- Compare clearly defined cohorts over a visible date range; do not imply
  causation or provide medical advice.
- Require at least five valid days in each cohort before showing a candidate.
  Treat this as a minimum eligibility check, not proof of statistical
  significance.
- Set metric-specific practical effect thresholds with product/clinical review;
  avoid presenting arbitrary thresholds as validated health guidance.
- Show cohort counts, means or medians, units, data coverage, and an evidence
  chart. Suppress results when the comparison is too sparse or ambiguous.
- Use neutral language such as "On your recorded days..." rather than
  prescriptive coaching language.

## Delivery roadmap

| Phase | Deliverables | Exit criteria |
|---|---|---|
| **1. Foundation and prototype** | Flutter app structure; design system and navigation; synthetic data; daily summary; daily/weekly/monthly views; dashboard and trend prototype for both form factors. | Android and iOS builds launch; representative navigation and chart interactions pass widget checks; synthetic fixtures cover empty and partial-data states. |
| **2. Platform data and local cache** | Health Connect and HealthKit adapters; permission education and partial-grant flows; normalized local schema; incremental, retryable synchronization; source attribution and deletion controls. | Platform-specific permissions and denial behavior are tested; repeat sync is idempotent; overlap/aggregation fixtures do not double count; interrupted and revoked-access cases recover safely. |
| **3. Trends and insights** | Rolling averages, historical benchmarks, cohort comparisons, evidence drill-down, and accessible charts. | Deterministic fixtures verify calculations, sample-size suppression, missing-data behavior, and units; insights show evidence and avoid causal/medical claims. |
| **4. Reports and release readiness** | PDF export; weekly digest if user-enabled; optional subscriptions; privacy disclosures; accessibility and device QA; store listing/declaration preparation. | PDF and billing flows pass platform tests; privacy/data deletion review is complete; store declarations are accurate and submitted; release gates pass. Store approval is an external dependency, not an engineering guarantee. |

## Verification and release gates

- Unit tests for normalization, time zones/day boundaries, aggregation,
  deduplication, sync state, trend calculations, and insight eligibility.
- Widget tests for permissions, loading/error/empty states, partial access,
  dashboard navigation, and evidence presentation.
- Integration tests with synthetic platform-adapter fixtures; manual device
  tests on supported Android and iOS versions before release.
- Privacy review of requested data types, local storage, logs, crash reports,
  PDF contents, subscription flows, and deletion/export behavior.
- Accessibility checks for text scaling, contrast, semantic labels, and chart
  alternatives.
- No production release until both platform data-access flows and store
  declarations have been independently verified against current official
  requirements.

## Risks and open decisions

- **Plugin coverage and maintenance:** Confirm that the chosen Flutter packages
  implement the exact Health Connect and HealthKit record types and lifecycle
  behavior required; plan a native bridge if they do not.
- **Platform differences:** Health Connect and HealthKit access, history,
  background work, and authorization semantics are not interchangeable. Keep
  capability checks explicit.
- **Aggregation correctness:** Platform aggregation behavior and supported
  metrics vary. Verify the exact APIs and deduplication semantics for each
  metric; do not claim a universal percentage reduction in double counting.
- **Insights validity:** Small observational cohorts are noisy and can be
  confounded. Treat results as personal descriptive comparisons, and suppress
  weak evidence.
- **Policy changes:** Recheck Android and Apple health-data policies and store
  declarations at implementation and release time.
- **Monetization:** Determine subscription entitlements and pricing only after
  confirming billing policy, restore behavior, and the product's validated Pro
  features.

## Repository status

The repository now has a Flutter application scaffold for Android and iOS and a
synthetic-data dashboard prototype with range selection and a guarded
descriptive insight calculation. `flutter analyze` and `flutter test` pass.
Android debug and release APKs and a release App Bundle have been built
successfully with Flutter 3.47.8, Android SDK 36, and JDK 21. The Android app
has not yet been run on a device or emulator. An iOS build cannot be run from
this Linux host; it requires macOS and Xcode. Health Connect, HealthKit, local
persistence, real charts backed by health records, reports, and billing are
not connected yet. Release outputs currently use the scaffold's debug signing
configuration and are for build verification only; configure a release
keystore before store distribution. Continue through the roadmap above, keeping
each phase buildable and tested before adding the next.
