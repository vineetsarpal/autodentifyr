# U.S./USD and Canada/CAD contextual pricing qualification

**Refreshed:** 2026-09-09 for ATD-24
**Prior evidence reviewed:** commit `63a93ed` (`us_canada_contextual_pricing_sources.md`) and the ATD-22 route note (`phase_one_pricing_evidence_routes.md`)

## Scope and decision

This is a bounded, primary-source-only refresh. No vendor was contacted, no
account was used, no terms were accepted, and no dataset, demonstration,
estimate, invoice, quote, or sample was requested or downloaded. This file
contains no numeric pricing and does not approve a provider, source, range, or
production integration.

The earlier conclusion still holds: official sources establish plausible
vehicle-specific estimating products and limited public context, but they do
not establish an authorized, reusable source that satisfies AutoDentifyr's
U.S./USD and Canada/CAD contextual pricing contract. Product capability,
geographic availability, currency, market representativeness, contractual
entitlement, dataset rights, and record rights remain separate questions.

ATD-24 should therefore remain blocked on permissioned evidence and qualified
Appraiser validation. Manual, Appraiser-confirmed vehicle context remains the
safe baseline; VIN decoding may assist but must not silently establish exact
equipment, part fitment, repair method, geography, currency, or price.

## Evidence-status vocabulary

| Status | Meaning here |
| --- | --- |
| `verified` | A precise publisher claim or repository fact directly supported by an official source checked in this refresh. |
| `proposed` | A qualification rule or future test; it has not been executed or approved. |
| `unavailable` | Required evidence was not present within the authorized scope of this review. |
| `permission-required` | Evidence could be evaluated only after an authorized party supplies access and the applicable grant is reviewed. |
| `excluded` | Material may provide qualitative context but must not be used as production pricing evidence in its present form. |

## Verified publisher claims

These claims are verified only at the stated layer. They do not verify
AutoDentifyr entitlement, coverage, accuracy, currency, or reusable price data.

### Vehicle and operation context

- NHTSA says vPIC is populated from manufacturer VIN-deciphering submissions.
  Its decode methods return vehicle information, recommend supplying model year,
  support partial VINs, and are subject to automated traffic controls. NHTSA
  also says foreign-vehicle data is present only when a manufacturer registered
  the vehicle for U.S. importation, use, or sale. This supports optional U.S.-oriented
  VIN prefill, not comprehensive Canadian-market or equipment coverage.
  [NHTSA vPIC API](https://vpic.nhtsa.dot.gov/api/),
  [NHTSA vPIC FAQ](https://vpic.nhtsa.dot.gov/api/home/index/faq)
- NHTSA describes its Canadian Vehicle Specifications endpoint as a database of
  vehicle dimensions used primarily for collision investigation and
  reconstruction and compiled by Transport Canada. It is not described as a
  parts, equipment, repair-operation, or pricing source.
  [NHTSA vPIC API: Canadian Vehicle Specifications](https://vpic.nhtsa.dot.gov/api/)
- Mitchell says its estimating product can populate vehicle data from VIN,
  author collision estimates, show parts diagrams, expose supplier parts
  information, and provide labor times. Its Canada-specific help identifies a
  Canadian cloud product path with automatic application updates.
  [Mitchell estimating](https://www.mitchell.com/solutions/collision-repairers/estimating),
  [Mitchell Canada getting-started guide](https://static.mymitchell.com/static/webhelp/multimedia/NGE/Slideshows/GettingStartedCanada/1033/Content/Content/Workflows/MCMCE/SharedTopicsShop/GetStarted.htm)
- CCC documents both VIN decoding into a MOTOR database vehicle and manual
  standard/generic vehicle selection when a VIN is absent or invalid; it also
  warns that a decoded VIN vehicle may differ from the vehicle assigned to the
  workfile. This supports explicit manual fallback and review rather than
  treating VIN-derived context as infallible.
  [CCC vehicle-description help](https://help.cccis.com/webhelp/repair_facility/estimating/web/Content/WorkfileTabs/Vehicle%20tab/Vehicle%20Description%20Tab%20Screen.htm),
  [CCC manual vehicle-selection help](https://help.cccis.com/webhelp/insurance_company/thecccportal/Content/Insurance/AppraisalExperience/LearningAppraisalExperience.htm)
- MOTOR's official estimating guidance describes a base-model/standard-option
  premise and requires optional equipment or collision-circumstance operations
  to be added when inspection establishes they are required. Vehicle-specific
  footnotes can supersede generic guide guidance. VIN or model match therefore
  does not eliminate Appraiser confirmation of installed equipment and scoped
  operations.
  [MOTOR estimating-guide help](https://help.cccis.com/webhelp/motor/gte/Content/ADD%20IF%20REQUIRED.htm)
- Mitchell's Canada help distinguishes replacement, removal/installation,
  repair, blend, and paintless dent repair, shows that multiple part variants
  can require further selection, and documents included assembly labor. It also
  describes a separately enabled refinishing-materials calculator. These claims
  reinforce that operation type, exact variant, inclusions, and calculation
  method cannot be inferred from a detector class alone.
  [Mitchell Canada parts and repair-lines help](https://static.mymitchell.com/static/webhelp/multimedia/NGE/Slideshows/GettingStartedCanada/1033/Content/Content/Workflows/MCMCE/SharedTopicsShop/AddParts.htm)
- Audatex Canada says its collision database uses VIN plus selected vehicle
  options to return part numbers, pricing, and labor times, and that vehicle
  model data is added on an ongoing basis. The page is a Canadian product claim;
  it does not itself state that every amount is CAD or establish U.S. coverage.
  [Audatex Canada collision database](https://www.audatex.ca/solution/collision-database/)
- CCC says the databases available to a user depend on access shown in the
  product, and that the selected workfile vehicle is used to look up parts,
  labor, and related information. This verifies a vehicle-linked estimating
  workflow, not Canada/CAD availability or data reuse rights.
  [CCC database help](https://help.cccis.com/webhelp/insurance_company/estimating/web/Content/Estimating/Databases/Overview%20Databases.htm)
- Solera's U.S. claims site describes VIN decoding from manufacturer build-sheet
  data, line-by-line repair estimates, preliminary estimates, and current
  alternative-parts quotes. It does not establish equivalence with Audatex
  Canada's fields, catalog, currency, or licensing.
  [Solera U.S. claims and collision products](https://www.claims.solera.com/)

### U.S./USD and Canada/CAD regional meaning

- Mitchell's announcement of its Canadian product launch says the U.S. product
  was localized for Canada with Canadian parts/pricing, currency, taxes,
  provinces/postal codes, and VIN scanning. This is direct publisher evidence
  that country/currency contexts are product localizations, not exchange-rate
  variants. It remains marketing evidence, not a grant or measured coverage.
  [Mitchell Canadian-market launch](https://www.mitchell.com/insights/news-release/auto-physical-damage/mitchell-brings-cloud-estimating-canadian-market)
- ICBC publishes collision-facility labor/material schedules under its British
  Columbia Material Damage repair-program resources. The current schedule
  distinguishes participant/development categories, labor categories,
  materials, estimating fees, and different applicability dates. It is evidence
  for a defined insurer program in British Columbia, not a representative
  Canadian retail market, a national CAD baseline, or a reusable price feed.
  [ICBC rate-schedule index](https://partners.icbc.com/material-damage/rate-schedule),
  [ICBC collision-program schedule](https://partners.icbc.com/assets/c2Ms1g7KvsWdORGZ1OX1G/collision-facility-labour-rates-material-allowances.pdf)
- Mitchell describes OEM, aftermarket, and salvage supplier information,
  including availability, shipping updates, pricing, and labor times inside its
  estimating workflow. Supplier availability is not the same as regional market
  representativeness, and no public page establishes a universal retail price.
  [Mitchell parts sourcing](https://www.mitchell.com/solutions/collision-repairers/estimating/parts-sourcing)
- OEC describes MyPriceLink as contextual, real-time manufacturer-suggested
  collision-parts list pricing whose result can depend on vehicle, repair,
  estimate, payer, and OEM-program inputs. OEC explicitly distinguishes
  manufacturer-suggested list price from a dealer's sell price, and describes
  controlled insurer/MSO/fleet programs. Its CollisionLink materials also place
  automaker discounts and promotions within enrolled U.S. and Canadian program
  workflows. These are strong reasons to keep list, dealer sell, supplier quote,
  and program prices distinct; public pages remain `excluded` as price rows.
  [OEC MyPriceLink](https://oeconnection.com/products/mypricelink/),
  [OEC CollisionLink Shop](https://oeconnection.com/products/collisionlink-shop/)
- No checked official source establishes that converting a U.S. amount into CAD
  yields Canadian labor rates, parts availability, supplier prices, or retail
  market context. Country, currency, rate origin, supplier market, and program
  status must therefore remain explicit rather than inferred.

### Freshness and versioning

- The vPIC API and standalone-download pages expose their own software/data
  version and update dates. NHTSA says standalone databases are limited to VIN
  decoding, while other queries still require the API. A snapshot date therefore
  identifies the acquired decoder artifact, not the freshness of every
  manufacturer field and not a pricing-data version.
  [NHTSA vPIC API](https://vpic.nhtsa.dot.gov/api/),
  [NHTSA vPIC downloads](https://vpic.nhtsa.dot.gov/downloads/)
- Audatex Canada claims weekly equipment part-price updates and ongoing updates
  to related estimating functions. This is publisher cadence language for the
  product; it does not prove that every field changes weekly, expose historical
  snapshots, or grant offline retention.
  [Audatex Canada Estimatics](https://www.audatex.ca/solution/audatex-estimatics/)
- Mitchell's Canada getting-started guide claims automatic software updates but
  is itself dated February 2022. Its public parts page describes information as
  updated but provides no field-level cadence or historical-version guarantee.
  Software release, catalog content, supplier quote, labor rule, and shop rate
  card must be versioned independently.
  [Mitchell Canada getting-started guide](https://static.mymitchell.com/static/webhelp/multimedia/NGE/Slideshows/GettingStartedCanada/1033/Content/Content/Workflows/MCMCE/SharedTopicsShop/GetStarted.htm),
  [Mitchell parts sourcing](https://www.mitchell.com/solutions/collision-repairers/estimating/parts-sourcing)
- ICBC's stable schedule link can point to a document with new applicability
  rules. Qualification must preserve the retrieved document version or permitted
  fingerprint and its effective-date rules; URL and retrieval date alone are
  insufficient.
  [ICBC rate-schedule index](https://partners.icbc.com/material-damage/rate-schedule)

### Public permission statements

- NHTSA says vPIC APIs are public, free to use, and do not require application
  registration. It separately documents automated traffic controls and provides
  downloadable VIN-decoding databases. These claims support evaluating vPIC for
  optional vehicle prefill; they do not turn vPIC into a pricing source.
  [NHTSA vPIC FAQ](https://vpic.nhtsa.dot.gov/api/home/index/faq),
  [NHTSA vPIC downloads](https://vpic.nhtsa.dot.gov/downloads/)
- CCC says product terms supplement the agreement governing the applicable
  service. Its data-interface help says export exists only for selected external
  applications and requires the interface-specific EULA. CCC's published data
  policy confirms that the hosted product stores estimate/appraisal data and
  describes some repair-facility sharing choices; none is an AutoDentifyr reuse
  grant.
  [CCC product terms](https://www.cccis.com/product-terms),
  [CCC data-interface help](https://help.cccis.com/webhelp/repair_facility/estimating/web/Content/Configure%20Machine%20Settings/Adding%20a%20Data%20Interface.htm),
  [CCC ONE data policy](https://www.cccis.com/policy/ccc-one-data)
- Mitchell's public developer page describes a registered partner API for a
  specific job at a specific shop and distinguishes API versions. This does not
  establish access to the estimating catalog or rights to derive and retain
  pricing. Enlyte's website terms say a separate written agreement controls when
  one exists.
  [Mitchell developer portal](https://developer.mitchell.com/),
  [Enlyte terms of use](https://www.enlyte.com/terms-use)
- Audatex Canada's website terms restrict commercial copying, distribution,
  display, publication, licensing, and derivative use of website information.
  Those website terms are not a product-data agreement and provide no grant for
  embedded estimating data.
  [Audatex Canada legal terms](https://www.audatex.ca/legal/)
- CARFAX Canada's repair-shop agreement is a first-party example of the
  permission boundary for contributed repair records: it defines VIN-level
  repair fields, recurring delivery, contributor authority, lawful collection,
  personal-information exclusions, and a grant to CARFAX Canada for stated
  uses. It gives AutoDentifyr no rights, but demonstrates why shop possession or
  export capability alone cannot replace dataset- and record-level permission.
  [CARFAX Canada repair-shop agreement](https://www.carfax.ca/privacy-legal/repair-shops)

## Proposed qualification protocol

The following is a proposed protocol, not completed evidence.

1. **Freeze the intended cell.** Record country, currency, region resolution,
   confirmed year/make/model/body, optional VIN result, required equipment,
   reviewed component and position, damage type, repair operation, parts basis,
   labor category, materials method, inclusions, exclusions, and tax/fee boundary.
2. **Preserve manual context.** A failed, partial, or ambiguous VIN decode must
   return to Appraiser-confirmed manual entry. A decode may prefill known fields
   but may not prove exact lamp, glass, sensor, trim, part fitment, or repair
   method. Unresolved fields remain explicit.
3. **Separate rate concepts.** Store operation hours, customer billing rate, and
   materials calculation separately. Classify rate evidence as retail posted,
   quoted, invoiced, insurer-negotiated, or program-scheduled. A program schedule
   must not be generalized into retail or national context.
4. **Qualify each geography independently.** Test U.S./USD and Canada/CAD cells
   against their own vehicle, supplier, labor-rate, and operation evidence. Do
   not use currency conversion as a substitute for Canadian market evidence or
   infer either country from a provider's presence elsewhere.
5. **Verify permission layers.** Retain separately the publisher claim,
   contractual entitlement, dataset-level grant, and record-level authorization.
   The intended grant must explicitly cover access, normalization, derived
   outputs, Appraiser and Vehicle Owner display, device-local storage, offline
   calculation/viewing, updates, internal evaluation, publication or
   redistribution as applicable, and retention of completed revisions after
   refresh or termination.
6. **Version every dependency.** Record product/feed and source version,
   observation and effective dates, supplier quote expiry, rate-card version,
   correction behavior, and a permitted immutable identifier or fingerprint.
   Recalculation creates a new draft revision; it must not rewrite a completed
   estimate's values or provenance.
7. **Validate scope and outcomes.** With an authorized sample, compare consistent
   pre-tax repair scopes, distinguish estimates from supplements and completed
   invoices, adjudicate shared operations once, and report missingness,
   availability, error/bias, and range coverage separately by country and
   relevant cohort. Thresholds require release-owner approval after evidence
   review.
8. **Fail visibly.** Missing, stale, ambiguous, out-of-region, contractually
   unlicensed, or otherwise unsupported pricing remains unavailable. It must not
   become zero, inherit another cohort's evidence, reuse application placeholders,
   or be concealed by an exchange-rate conversion.

Repository-safe findings may contain citations, schemas, field definitions,
statuses, and non-confidential permission summaries. Proprietary prices, private
estimates/invoices, credentials, VINs, plates, Vehicle Owner identifiers, vendor-
confidential agreements, and raw licensed extracts belong only in an authorized,
access-controlled evidence package.

## Unavailable evidence

Within this authorized review, all of the following remain `unavailable`:

- an approved source or source combination covering U.S./USD and Canada/CAD;
- an explicit currency statement and field-level country coverage for every
  relevant commercial candidate;
- representative U.S. or Canadian retail labor-rate evidence with disclosed
  population, geography, observation period, and sampling method;
- a permissioned shop rate card, estimate, supplement, completed invoice, quote,
  or final-bill record;
- an authorized machine-readable sample, schema, coverage list, source history,
  correction log, or field-level refresh contract;
- verified coverage for AutoDentifyr's complete component/operation/equipment
  matrix in either country;
- evidence that a successful VIN decode identifies all operation-critical
  equipment or that NHTSA vPIC comprehensively covers Canadian-market vehicles;
- contractual entitlement and dataset/record rights for extraction, derived
  ranges, display, offline/device storage, updates, publication, redistribution,
  and completed-revision retention; and
- independent Appraiser review, error/bias analysis, range-coverage evaluation,
  product-owner selection, and approved acceptance thresholds.

Public feature pages, public help, program schedules, website terms, application
placeholders, and currency conversion are `excluded` as numeric production
pricing evidence.

## Permission-required evidence and next authorized gate

The two plausible evidence routes remain `permission-required`:

1. **Repair Shop records:** an authorized shop or other record controller must
   supply a defined sample and written permission for each record and intended
   aggregation, derivation, evaluation, display, storage, retention, publication,
   and redistribution use. Embedded third-party estimating content requires its
   own rights review.
2. **Commercial estimating/data agreement:** an authorized account owner or
   procurement/legal representative must supply the operative agreement, product
   tier, territories, currencies, interfaces, and a permitted sample. Public
   marketing, a subscription, an export feature, or a developer portal is not a
   substitute for that grant.

Only after one route clears all four permission layers should the authorized
sample be evaluated with the proposed country-by-country protocol. This research
does not authorize outreach, purchase, sign-in, terms acceptance, downloading,
or sample acquisition.

## Access limitations observed

- Only publicly reachable official pages and the two named repository artifacts
  were reviewed. No gated documentation or agreement was accessed.
- CCC help retrieval has been inconsistent across research passes; the database
  and data-interface pages were available through official indexed text during
  this refresh. Direct automated retrieval of the CCC training page and data
  policy failed during final link validation. Recheck them under authorized
  product access before a contractual decision.
- Solera's public U.S. product page provided feature descriptions, but public
  product terms did not establish a usable estimating-data grant.
- Provider coverage statements were not converted into measured fleet coverage.
  No VIN, vehicle, quote, estimate, or dataset sample was submitted or obtained.
- Direct automated retrieval of the CARFAX Canada repair-shop agreement failed
  during final link validation; its official URL remains recorded as a
  permission-boundary reference requiring later recheck.
- No legal conclusion is offered. Permission findings state only what the checked
  public evidence did or did not establish for AutoDentifyr.

## ATD-24 disposition

This refresh verifies the continued plausibility of commercial vehicle-specific
estimating tools, the limited role of public VIN data, and the distinction
between a regional insurer program and retail-market evidence. It does not close
the source-access, country/currency coverage, permission, sample-validation, or
Appraiser-acceptance gaps. ATD-24 remains `permission-required` and should not be
treated as production-ready.
