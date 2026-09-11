# Phase 1 U.S./USD pricing evidence routes and rights boundary

**Researched:** 2026-09-09 for ATD-22

**Scope:** Bounded primary-source review of candidate evidence routes and public
access/permission claims. No vendor was contacted, no account or demonstration
was requested, no terms were accepted, no product or dataset was acquired, and
no Repair Shop record was accessed. This note does not select a provider,
approve a price, or give a legal conclusion.

## Finding

No authorized Phase 1 U.S./USD pricing source is established by the evidence
available to this review. Official pages verify that CCC ONE/MOTOR, Mitchell,
and Solera/Audatex offer relevant estimating capabilities. They do not verify
AutoDentifyr's contractual entitlement to extract, derive, store, display,
publish, update, or retain their pricing data. No permissioned Repair Shop
estimate or completed-invoice collection is available either.

The viable routes therefore remain **permission-required**:

1. permissioned Repair Shop estimates and completed invoices, with source and
   record-level authorization for the intended derivation and product uses; or
2. a commercial estimating/data agreement whose actual grant covers the same
   uses and supplies an authorized, usable U.S./USD sample.

Public marketing, help pages, interface existence, and website terms are
**excluded** as numeric price evidence. Current application constants remain
unvalidated placeholders, as documented by ATD-15; copying, averaging, or
relabeling them would not create evidence.

## Evidence-status vocabulary

| Status | Meaning in this note |
| --- | --- |
| `verified` | Directly supported by a checked official source or repository artifact. |
| `proposed` | A future qualification or evidence-handling rule; not performed or approved. |
| `unavailable` | Required evidence was not present or obtainable within authorized scope. |
| `permission-required` | The route could be investigated only after an authorized party supplies or approves access and the applicable grant is reviewed. |
| `excluded` | The material must not be used as production pricing evidence in its present form. |

“Verified” applies only to the precise claim and layer named. A verified vendor
feature does not verify entitlement, dataset rights, record rights, coverage,
accuracy, or a numeric range.

## Candidate route ledger

| Route | Publisher/vendor claim | Contractual entitlement | Dataset-level rights | Record-level rights | Evidence disposition |
| --- | --- | --- | --- | --- | --- |
| Permissioned Repair Shop records | No external provider claim is needed for a shop-authored record route. The proposed inputs are scoped estimates and completed invoices, kept distinct, with supplements and final scope identified. | `unavailable`: no participating Repair Shop, contributor agreement, product-owner approval, or Appraiser approval was available. | `unavailable`: no grant covers aggregation, normalization, derived ranges, internal evaluation, publication, redistribution, or retained versions. | `unavailable`: no record owner/controller, customer/insurer/vendor restriction review, de-identification approval, or record-specific authorization exists. | `permission-required`; potentially the most direct route to observed local work, but no sample is authorized. |
| CCC ONE / MOTOR | `verified`: CCC says the estimate workflow uses MOTOR and other databases to select parts, labor, and related vehicle information. CCC also documents export for selected external applications through an interface-specific EULA. [CCC database help](https://help.cccis.com/webhelp/insurance_company/estimating/web/Content/Estimating/Databases/Overview%20Databases.htm), [CCC data-interface help](https://help.cccis.com/webhelp/repair_facility/estimating/web/Content/Configure%20Machine%20Settings/Adding%20a%20Data%20Interface.htm) | `unavailable`: CCC's public product-terms page says its product terms supplement an agreement; no AutoDentifyr agreement, subscription, interface EULA, or data-feed grant was supplied. [CCC product terms](https://www.cccis.com/product-terms) | `unavailable`: the public evidence does not grant creation or redistribution of derived U.S./USD ranges, app display, device-local/offline storage, updates, publication, or post-termination retention. | `unavailable`: no authorized estimate/invoice rows, record provenance, or permission evidence was supplied. CCC's data policy confirms that CCC ONE stores estimate/appraisal data and describes some sharing choices, but it is not an AutoDentifyr reuse grant. [CCC ONE data policy](https://www.cccis.com/policy/ccc-one-data) | `permission-required`; public pages are `excluded` as price rows. Direct retrieval of the two CCC help pages returned HTTP 403 on 2026-09-09, although official indexed content was available; re-check under authorized access. |
| Mitchell Cloud Estimating / Integrated Parts | `verified`: Mitchell says its estimating product authors collision estimates and exposes parts information, supplier availability/pricing, and labor times inside the product. [Mitchell estimating](https://www.mitchell.com/solutions/collision-repairers/estimating), [Mitchell parts sourcing](https://www.mitchell.com/solutions/collision-repairers/estimating/parts-sourcing) | `unavailable`: no customer/product agreement or account entitlement was supplied. The official website terms say a separate written agreement controls where one exists and do not themselves transfer product-data rights. [Enlyte terms of use](https://www.enlyte.com/terms-use) | `unavailable`: no grant for extraction, normalization, derived ranges, product display, offline caching, updates, publication, redistribution, or completed-revision retention was found. | `unavailable`: no authorized estimate, repair-order, final-bill, or invoice record was supplied. | `permission-required`; product and website pages are `excluded` as price rows. |
| Mitchell RepairCenter API | `verified`: Mitchell describes a near-real-time partner API targeting a specific job at a specific shop. [Mitchell developer portal](https://developer.mitchell.com/) | `unavailable`: public API description is not proof that AutoDentifyr is registered, approved, or licensed for the intended use. | `unavailable`: a job-workflow API does not itself establish access to or reuse rights in Mitchell's estimating catalog. | `unavailable`: no shop authorization, endpoint grant, job record, or downstream-use permission exists. | `permission-required`; keep separate from the estimating-database route. |
| Solera/Audatex Qapter and APU | `verified`: Solera's U.S. claims site describes automated line-by-line repair estimates, preliminary estimates, and current alternative-parts quotes. [Solera claims and collision](https://www.claims.solera.com/) | `unavailable`: no account, product agreement, API/data-feed agreement, or entitlement was supplied. The linked “Terms of Use” page rendered only a heading/navigation in the checked response and supplied no operative product-data grant. [Solera terms page](https://www.claims.solera.com/terms-of-use/) | `unavailable`: no grant for derived ranges, display, offline/device storage, updates, publication, redistribution, or retained revisions was verified. | `unavailable`: no estimate, quote, invoice, source-owner record, or record permission was supplied. | `permission-required`; official marketing is `excluded` as price rows. |
| Public provider quote/help pages and demonstrations | `verified`: first-party pages can describe qualitative scope factors and vehicle-specific quotation workflows, as ATD-15 records. | `unavailable`: public visibility does not establish bulk collection or application-use entitlement. | `unavailable`: no representative dataset, source population, sampling method, or reusable grant exists in the reviewed evidence. | `unavailable`: no authorized quote record exists. | `excluded` for numeric ranges; useful only as cited qualitative source context. |

## Rights layers that must not be collapsed

The eventual source ledger should preserve four distinct layers:

- **Publisher/vendor claim:** what an official page says the product or source
  can do. This may be verified without proving access or permission.
- **Contractual entitlement:** the specific agreement, account, product tier,
  interface, geography, term, and permitted user that authorize access. An
  interface or export button proves a capability, not AutoDentifyr entitlement.
- **Dataset-level rights:** permission to collect or receive the defined source
  population and to normalize it, calculate derived ranges, evaluate, display,
  store on-device, work offline, update, publish, redistribute, and retain the
  evidence used by completed Preliminary Damage Assessment revisions.
- **Record-level rights:** permission and restrictions for each contributed
  estimate, completed invoice, supplement, quote, or other observation. Each
  record still needs a source owner/controller, version or observation date,
  permitted uses, restriction review, and authorization evidence even when a
  dataset-level agreement exists.

An affirmative result at one layer must never fill a missing result at another.
For example, a Repair Shop's ability to view or export an estimate does not by
itself prove that embedded third-party database values may be aggregated into a
redistributed product. Conversely, a vendor agreement would not automatically
clear customer identifiers or every contributed shop record.

## Proposed qualification evidence

This is a proposed checklist, not evidence that qualification occurred. Before
selecting a route, require an authorized sample plus retained documentation for:

- source owner, source/product name, source version, collection or observation
  period, U.S. geography, USD currency, and refresh/effective date;
- estimate versus completed-invoice status, supplement status, parts basis,
  labor categories, labor hours and rate basis, materials, inclusions,
  exclusions, taxes/fees boundary, and shared-operation identifiers;
- derived-range creation, Appraiser-facing and Vehicle-Owner-facing display,
  device-local storage, offline calculation/viewing, updates, retained completed
  revisions, internal evaluation, publication, and redistribution permissions;
- contract/evidence identifier, scope (`publisher_claim`, `contract`, `dataset`,
  or `record`), verifier, verification time, expiry/termination behavior, and
  unresolved constraints; and
- explicit coverage cells by raw detector class, position-specific Vehicle
  Component, Damage Type, reviewed Repair Operation, vehicle context, source,
  and evidence status.

Use the exact 14-class mapping already frozen for ATD-20. That mapping separates
raw classes from canonical damage and component concepts. Generic classes must
not infer position: for example, `doorouter-dent`, `fender-dent`, and
`quaterpanel-dent` establish neither left/right nor front/rear, while lamp
classes establish their longitudinal family but not left/right. Pricing must be
attached to a reviewed Repair Operation and cohort, not directly to a model
class or image count.

Shared work requires one stable operation identity linked to all supported
Confirmed Findings. A second Capture, observation, or finding must not duplicate
one panel refinish, setup, calibration, or other shared operation. Source rules
and an Appraiser-reviewed scope decide what is actually shared; no universal
overlap discount is proposed.

Missing, expired, position-ambiguous, contractually unlicensed, or otherwise
unsupported evidence remains `unavailable`. It must never become USD 0, inherit
another cohort's price, widen into a fabricated range, or fall back to current
placeholder constants. The Assessment Estimate remains visibly partial under
the accepted domain contract.

## Proposed package boundary and current decision

Reuse ATD-20's separation between a repository-safe source ledger and an
access-controlled evidence package. The future package should bind its manifest
to exact byte lengths and SHA-256 hashes and keep source/permission records,
normalized operation observations, cohort definitions, coverage cells, and
Appraiser review/adjudication records distinct. Repository-safe artifacts must
contain no proprietary prices, private estimates or invoices, credentials,
VINs, plates, Vehicle Owner identifiers, or vendor-confidential agreement text.

This review supplies **verified publisher/vendor feature claims** and a
**proposed qualification boundary** only. Contractual entitlement, dataset-level
rights, record-level rights, an authorized source location, a usable U.S./USD
sample, populated operation coverage, numeric ranges, product-owner selection,
and qualified Appraiser acceptance are all **unavailable**. ATD-22 therefore
cannot be completed from this evidence and still requires authorized human/data
work.
