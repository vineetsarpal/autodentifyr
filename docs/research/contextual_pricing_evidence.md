# Contextual pricing evidence contract and coverage

**Contract version:** 1

**Prepared:** 2026-09-09 for ATD-24

**Status:** Proposed protocol with verified repository and primary-source facts.
No authorized pricing dataset, provider selection, contextual pricing record,
regional retail default, reusable quote, product-owner acceptance, or qualified
Appraiser acceptance exists.

This contract extends the ATD-22 Phase 1 U.S./USD evidence-package conventions
for the distinct Phase 2 U.S./USD and Canada/CAD Contextual Pricing Coverage
decision. The companion
[`us_canada_contextual_pricing_qualification.md`](us_canada_contextual_pricing_qualification.md)
contains the primary-source review. Repository artifacts contain no proprietary
prices, private estimates or invoices, VINs, licence plates, Vehicle Owner data,
credentials, or confidential agreement text.

## Current decision

All 28 country/class declarations in
[`contextual_coverage_matrix.csv`](contextual_pricing_evidence/contextual_coverage_matrix.csv)
are `unsupported`; pricing is `unavailable`. The rows declare the intended
dimensions and known gaps only. They are not samples, prices, entitlements,
provider coverage claims, or human approvals. Missing evidence cannot become
zero, inherit another country or region, use an application placeholder, or be
filled by currency conversion.

The
[`source_permission_ledger.csv`](contextual_pricing_evidence/source_permission_ledger.csv)
keeps candidate routes open without selecting one. Official provider pages can
verify a scoped publisher claim. They do not verify contractual entitlement,
dataset-level rights, record-level rights, a usable source version, or any
product permission. The ICBC route is a defined insurer-program schedule, not
Canadian retail evidence.

## Phase boundary and reuse

ATD-22 owns Phase 1 national U.S./USD baseline source qualification. ATD-23 owns
later Phase 1 range construction and empirical approval. ATD-24 owns Phase 2
vehicle- and region-contextual qualification for both countries. The issues may
reuse source identities, permission evidence, version/hash rules, operation
records, and human review formats. They must not collapse their coverage
decisions or treat Phase 1 baseline access as Phase 2 contextual coverage.

Common evidence should be referenced by stable source and permission record IDs
instead of copied. A source supporting both phases still needs separate coverage
cells and acceptance decisions for each phase. Procurement, vendor contact,
access forms, demonstrations, terms acceptance, purchases, and Appraiser or
Repair Shop outreach remain outside this repository work.

## Source and permission ledger

Every route separates four layers:

1. `publisher_claim_status`: the precise feature or availability statement an
   official publisher makes.
2. `contractual_entitlement_status`: the applicable account, product tier,
   territory, currency, interface, and agreement grant.
3. `dataset_rights_status`: the right to collect, normalize, reconcile,
   evaluate, derive ranges, and maintain versions for the defined population.
4. `record_rights_status`: the right to use each underlying estimate, invoice,
   supplement, quote, rate card, part observation, or program record.

The controlled evidence statuses are `verified`, `proposed`, `unavailable`,
`permission-required`, and `excluded`. Permission is separately recorded for
derived ranges, application display, device-local storage, offline use, updates,
retained completed revisions, internal evaluation, publication, and
redistribution. No status promotes another layer.

## Contextual coverage dimensions

A supported cell requires all of the following to reconcile to exactly one
permitted source-version pricing record:

- `US` with `USD`, or `CA` with `CAD`;
- ZIP or postal-code resolution and the evidenced regional basis;
- confirmed vehicle year, make, model, body style, and operation-critical
  equipment;
- optional VIN-prefill status, kept separate from manual confirmation;
- the exact Vehicle Component position;
- the exact raw class, Damage Type, and reviewed Repair Operation;
- labor category;
- parts provenance;
- materials method;
- evidence source and version;
- effective or observation date; and
- `supported`, `unsupported`, or `unresolved` coverage status.

The exact Android class spelling and order are inherited from ATD-20 and ATD-22,
including `Rear-windscreen-Damage`, `Runningboard-Damage`, and
`quaterpanel-dent`. The detector classes do not establish unsupported positions.
Door, fender, and quarter-panel detections do not establish left/right or
front/rear. Lamp, running-board, and mirror detections do not establish a side.
The Appraiser or permitted supporting evidence must confirm the position.

A VIN decode may prefill candidate vehicle fields. It cannot prove exact
equipment, component position, part fitment, market availability, operation
scope, or pricing coverage. Missing or ambiguous decoder/equipment evidence
returns to manual Appraiser confirmation. No VIN value is stored in the
repository-safe artifacts.

## Pricing distinctions

Operation hours, customer billing rates, and materials calculations remain
separate. Rate evidence identifies one basis: Repair Shop, regional default,
insurer/program schedule, or employee wage. A program allowance cannot be
represented as retail evidence. An employee wage cannot be represented as a
customer billing rate. Body, paint, frame, structural, mechanical, glass,
calibration, and other labor categories remain distinguishable.

OEM, aftermarket, recycled, alternate OEM, mixed-recorded, unresolved, and
not-applicable parts provenance remain distinct. Exact fitment and market
availability are separate from VIN/model matching. A missing alternative part
does not prove none exists, and a price for one provenance does not fill another.

Materials retain their calculation method and source. Taxes, fees, freight,
discounts, included operations, and exclusions are explicit. Estimates,
completed invoices, supplements, insurer/program schedules, commercial extracts,
proposed assumptions, and currency conversions remain separate evidence types.
Currency conversion is always excluded from creating regional coverage.

## Time, availability, and revisions

Source and operation records distinguish effective dates, observation dates,
availability dates, expiry, supersession, correction, and refresh-due dates. A
stable URL does not identify a stable version. Supplier quotes and parts
availability may expire independently of a product or labor-rule version.

Stale, expired, corrected, superseded, out-of-region, or missing pricing remains
unavailable until applicable evidence is selected explicitly. Refresh records
describe the prior and new source versions, correction and availability changes,
and the result of the check. A Draft may be recalculated only through an explicit
action. A completed Preliminary Damage Assessment retains its original values,
source versions, assumptions, and exclusions.

## Shared work and missing pricing

One `shared_operation_group_id` identifies work supporting several Confirmed
Findings. The priced operation appears once and may link to multiple findings.
Captures, detections, findings, or coverage rows cannot duplicate setup,
refinish, calibration, materials, or another shared operation. Source rules and
Appraiser-reviewed scope decide sharing; no universal overlap factor is assumed.

Unavailable pricing uses blank amounts in an authorized package and the explicit
`unavailable` status. It never uses numeric zero. Unsupported and unresolved
coverage rows remain in the matrix with a reason. A partially priced Assessment
Estimate remains a Partial Estimate with only its supported subtotal displayed.

## Access-controlled evidence package

Private evidence belongs outside Git in an approved access-controlled location:

```text
contextual-pricing-package/
├── contextual_pricing_manifest.json
├── source_records.csv
├── vehicle_context_records.csv
├── region_records.csv
├── contextual_operation_records.csv
├── contextual_coverage_matrix.csv
├── refresh_recalculation_records.csv
└── review_records.csv
```

[`contextual_pricing_manifest.schema.json`](contextual_pricing_evidence/contextual_pricing_manifest.schema.json)
binds every table to an exact relative path, byte length, and SHA-256 digest.
[`contract.json`](contextual_pricing_evidence/contract.json) freezes the table
schemas and controlled values. Source records own provenance and permissions.
Vehicle and region records own confirmed context. Operation records own scoped
evidence. Coverage records own supported, unsupported, and unresolved cells.
Refresh records own source changes and recalculation behavior. Review records
own product-owner and qualified-Appraiser decisions.

No empty repository tables or placeholder rows claim an authorized sample,
entitlement, coverage, or review. Only an approved private package may contain
real rows, and repository publication or redistribution needs its own explicit
permission.

## Validation

Run:

```text
python3 tool/contextual_pricing_validator.py --repository-root .
python3 tool/contextual_pricing_validator.py --package /approved/path/to/contextual-pricing-package
```

The public CLI validates exact schemas and controlled values; stable identifiers;
source/version, permission, geography, currency, and date consistency; optional
VIN/manual/fitment separation; byte lengths and hashes; coverage reconciliation;
duplicates; shared-operation counting; missing/stale behavior; evidence-type
separation; refresh behavior; and review gates. `--require-complete`
deliberately fails for the current repository state.

## Exact blockers and disposition

ATD-24 remains incomplete because the following are unavailable:

- authorized U.S./USD and Canada/CAD source access;
- applicable contractual entitlement, dataset rights, and record-level rights;
- usable scoped samples for both countries;
- permission for derived ranges, display, device-local storage, offline use,
  updates, and retained completed revisions;
- populated contextual coverage with real provenance and refresh records;
- independently selected U.S. and Canadian qualification assessments;
- qualified Appraiser review results and accepted coverage/freshness limits;
- product-owner and qualified-Appraiser acceptance; and
- evidence sufficient for a human release-gate decision or an explicitly
  approved product-scope revision.

Repository scaffolding and public research do not satisfy these requirements.
ATD-24 must remain In Progress until authorized human and evidence work occurs.
