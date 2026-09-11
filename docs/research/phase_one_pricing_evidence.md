# Phase 1 pricing evidence contract and coverage

**Contract version:** 1

**Prepared:** 2026-09-09 for ATD-22

**Status:** Proposed protocol with verified repository and public-source facts.
No authorized pricing source, reusable pricing record, numeric range, provider
selection, product-owner acceptance, or qualified Appraiser acceptance exists.

This document defines the smallest repository-safe contract for qualifying a
future U.S./USD Phase 1 pricing source. The companion
[`phase_one_pricing_evidence_routes.md`](phase_one_pricing_evidence_routes.md)
records the primary-source review. The
[`contract.json`](phase_one_pricing_evidence/contract.json) freezes controlled
values and completion state; the
[`pricing_manifest.schema.json`](phase_one_pricing_evidence/pricing_manifest.schema.json)
defines a future evidence-package manifest. The repository ledgers contain no
proprietary price evidence, private estimates or invoices, credentials, or
customer identifiers.

## Current decision

No source route can be selected from current authorization and evidence.
Permissioned Repair Shop records and commercial estimating sources remain
candidate routes, not approved providers. Public marketing and help pages
verify limited product-capability claims only. They do not establish
contractual entitlement, dataset-level rights, record-level rights, reusable
U.S./USD values, offline use, or complete operation coverage.

Every intended Phase 1 cohort is therefore `unsupported`, and its pricing is
`unavailable`. This is a coverage result, not a zero-dollar estimate. Current
application constants are `excluded` from pricing evidence and must not be
copied, averaged, relabelled, or promoted.

ATD-22 remains incomplete until an attainable route is selected with the
product owner and a qualified Appraiser, rights and access are verified, a
usable sample is available, the required application and retention permissions
are demonstrated, coverage is populated from real provenance records, and the
human acceptance evidence is recorded. An explicitly approved product-scope
revision may narrow coverage, but repository scaffolding cannot substitute for
that decision.

## Evidence and permission layers

The source ledger keeps the following layers independent:

1. `publisher_claim_status`: what an official owner page says a product or
   source can do.
2. `contractual_entitlement_status`: whether the applicable agreement, account,
   product tier, territory, and interface authorize AutoDentifyr access.
3. `dataset_rights_status`: whether the defined population may be collected,
   normalized, evaluated, and used for derived ranges.
4. `record_rights_status`: whether each estimate, completed invoice, supplement,
   or other source observation may be used as intended.

The controlled evidence statuses are `verified`, `proposed`, `unavailable`,
`permission-required`, and `excluded`. A verified publisher claim does not
promote the other three layers. The ledger separately records permission for
derived ranges, application display, device-local storage, offline use,
updates, retained completed revisions, internal evaluation, publication, and
redistribution. No permission field may be inferred from another.

## Candidate routes

- **Permissioned Repair Shop records:** estimates and completed invoices can be
  viable observations only after the source owner, record controller,
  third-party restrictions, privacy handling, dataset use, record use, and all
  product permissions are documented. Estimates, completed invoices, and
  supplements stay distinguishable. No Repair Shop or sample is currently
  authorized.
- **Commercial estimating sources:** CCC ONE/MOTOR, Mitchell, and
  Solera/Audatex have relevant first-party product claims. Selection requires
  the actual agreement and an authorized sample showing the contracted product,
  version, access path, U.S./USD operation coverage, update/retention behavior,
  and every intended use. Marketing, a demonstration, an export workflow, or
  API existence does not provide those rights.

The routes may coexist. A Repair Shop export can contain third-party database
content whose reuse terms differ from the shop's own record rights. ATD-22 must
resolve both layers instead of treating the export itself as permission.

## Domain and mapping boundary

The 14 Android raw classes are model outputs, not Vehicle Components, Damage
Types, Repair Operations, or pricing cohorts. The
[`class_operation_coverage.csv`](phase_one_pricing_evidence/class_operation_coverage.csv)
preserves the exact ID order and spelling from the frozen ATD-20 mapping,
including `Rear-windscreen-Damage`, `Runningboard-Damage`, and
`quaterpanel-dent`.

Each row separates:

- the raw detector class;
- its component family and only the longitudinal position encoded by that raw
  class;
- the position-specific Vehicle Component that future evidence or Appraiser
  adjudication must establish;
- the Damage Type;
- non-interchangeable candidate Repair Operations; and
- the U.S./USD Phase 1 pricing cohort and evidence coverage.

Generic classes never imply unsupported positions. `doorouter-dent`,
`fender-dent`, and `quaterpanel-dent` establish neither left/right nor
front/rear. Lamp classes establish a front/rear family but not left/right.
Running board and side mirror classes do not establish a side. A pricing record
must refer to the confirmed position-specific component and reviewed Repair
Operation; it cannot price a detection or image count directly.

Alternative operations are not low/high endpoints. Paintless dent repair,
conventional repair/refinish, and replacement describe different scopes. Until
the scope is supported, the cohort stays unavailable rather than becoming one
broad fabricated range.

## Coverage and missing-pricing rules

Coverage is evaluated by raw class, confirmed component position, Damage Type,
Repair Operation, vehicle context, geography, currency, and evidence source.
The controlled coverage statuses are:

- `supported`: exactly one applicable verified source-version pricing record
  reconciles to the cell;
- `unsupported`: required evidence or rights are absent and the reason is
  explicit; and
- `unresolved`: evidence exists but a material mapping, scope, permission, or
  review decision remains open.

All 14 current rows are `unsupported`. A future coverage matrix must retain
unsupported and unresolved cells; it must not omit them from the denominator.
`pricing_status=unavailable` requires blank price amounts. A zero is a real
numeric observation only when authorized evidence shows zero; it is never the
encoding for missing data. Any partially priced Assessment Estimate displays
only its known subtotal and remains a visible Partial Estimate.

One stable `shared_operation_group_id` represents work shared by multiple
Confirmed Findings. The operation record appears once and links to every
finding it supports. Multiple Captures, detections, findings, or coverage rows
must not duplicate panel refinish, setup, calibration, materials, or any other
shared work. Source rules and Appraiser-reviewed scope determine sharing; no
universal overlap discount is assumed.

## Required provenance

Every future source record includes source owner, source/product name and
version, collection-period start/end, geography, currency, evidence type,
estimate-versus-completed-invoice status, supplement status, parts basis, labor
categories, materials basis, inclusions, exclusions, refresh date, every
permission field, and a retained permission-evidence reference.

Every future pricing record includes the source and source version, cohort,
Repair Operation, shared-operation group, confirmed component, Damage Type,
vehicle context, geography, currency, evidence type, estimate/invoice and
supplement statuses, amounts in integer currency minor units, inclusions,
exclusions, and observation date. Mixing a source version, country, currency,
evidence type, invoice state, or supplement state across records is a validation
error rather than an implicit normalization.

Proposed assumptions remain `proposed`; they cannot be marked as verified
pricing. Estimates, completed invoices, and supplement states remain separate
inputs unless a documented method explicitly relates them. Publication and
redistribution permissions stay distinct from internal evaluation and product
display permissions.

## Evidence-package boundary

Future proprietary or private evidence belongs in an approved access-controlled
location, not Git:

```text
pricing-package/
├── pricing_manifest.json
├── source_records.csv
├── operation_records.csv
├── coverage_matrix.csv
└── review_records.csv
```

`pricing_manifest.json` binds each file role to its exact relative path, byte
length, and SHA-256 digest. `source_records.csv` owns source provenance and
permission decisions. `operation_records.csv` owns normalized evidence rows.
`coverage_matrix.csv` owns supported, unsupported, and unresolved cells.
`review_records.csv` owns product-owner and Appraiser review/adjudication.

The repository stores only schemas, candidate-source dispositions, intended
coverage, placeholder reconciliation, and validation code. Do not commit source
records, pricing rows, customer or Vehicle identifiers, VINs, licence plates,
private estimates/invoices, agreement text, credentials, or proprietary
pricing extracts without separate explicit authorization for repository
publication.

## Validation and downstream use

Run:

```text
python3 tool/phase_one_pricing_validator.py --repository-root .
python3 tool/phase_one_pricing_validator.py --package /approved/path/to/pricing-package
```

The validator checks schemas and controlled values, identifiers, exact raw
mapping, source-version and permission completeness, U.S./USD/date/evidence
consistency, exact byte lengths and SHA-256 digests, coverage reconciliation,
duplicate/conflicting records, shared-operation duplication, missing-pricing
semantics, evidence-state separation, and explicit unsupported cohorts.
`--require-complete` intentionally fails against current repository artifacts.

ATD-23 may consume a validated authorized package to define and evaluate range
methods; it must not reinterpret this protocol as an approved numeric dataset.
ATD-24 may reuse the source, permission, provenance, manifest, operation, and
review structures, while adding Canada/CAD and vehicle/regional dimensions.
It must not duplicate procurement or infer Canadian evidence through currency
conversion. Phase 1 and Phase 2 coverage decisions stay distinct even if one
contracted source supports both.

## Placeholder reconciliation

[`placeholder_reconciliation.csv`](phase_one_pricing_evidence/placeholder_reconciliation.csv)
captures the current static application maps as code observations only. Ten of
14 live/import values differ. Import annotations duplicate the import map.
Unknown classes contribute USD 250 in live totals, USD 0 in import totals, and
USD 250 in import annotations. These fallbacks are internally inconsistent and
none has source/version, rights, cohort, operation, shared-work, provenance, or
review evidence.

Every reconciliation row is `excluded`, `unsupported`, and
`must_not_promote`. The validator checks those dispositions and verifies the
declared same/different result. Production cleanup belongs to an authorized
implementation issue; ATD-22 does not change application behavior.

## Exact blockers and disposition

The following remain unavailable:

- product-owner selection of an attainable source route and coverage boundary;
- qualified Appraiser agreement on Repair Operations, inclusions, shared work,
  cohorts, and usable sample scope;
- a participating Repair Shop or contracted commercial source;
- applicable agreements and verified source-, dataset-, and record-level
  rights;
- permission for derived ranges, display, device-local storage, offline use,
  updates, retained completed revisions, internal evaluation, publication, and
  redistribution;
- an approved access-controlled location and a usable U.S./USD sample;
- populated source, operation, and coverage records with real provenance;
- range methodology and independent validation, which remain ATD-23 work; and
- recorded product-owner and qualified Appraiser acceptance, or an explicitly
  approved product-scope revision.

ATD-22 must remain In Progress or `ready-for-human`/`needs-info` until those
human, authorization, and source-access prerequisites are resolved. ATD-23
remains blocked. ATD-24 can align its qualification format with this contract
but remains blocked on its own authorized contextual source evidence.
