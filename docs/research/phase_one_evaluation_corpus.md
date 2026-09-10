# Phase 1 evaluation corpus protocol and evidence boundary

**Protocol version:** 1

**Frozen:** 2026-09-08 for ATD-20

**Status:** Proposed protocol and executable contract. No evaluation corpus has
been acquired, no Appraiser has reviewed annotations, and ATD-20 is not
complete.

This document defines the smallest repository-safe contract for a future
Appraiser-labelled Phase 1 evaluation corpus. The companion
[`contract.json`](phase_one_evaluation_corpus/contract.json) defines file names,
columns, controlled values, and completion evidence;
[`corpus_manifest.schema.json`](phase_one_evaluation_corpus/corpus_manifest.schema.json)
defines the version/hash manifest. The populated
[`class_mapping.csv`](phase_one_evaluation_corpus/class_mapping.csv) and
[`source_permission_ledger.csv`](phase_one_evaluation_corpus/source_permission_ledger.csv)
contain only verified repository/model facts and unresolved candidate-source
claims. They are not image or review manifests.

No private image, credential, permission document, or model binary belongs in
Git. Store future evidence in an approved access-controlled location and commit
only redacted manifests whose release has been separately authorized.

## Evidence status

### Verified evidence

- The Android artifact has SHA-256
  `56d8341be346bbc9ebe94a038405b5f5f3ef7fd172ffb3fb99e2ac0e38cb8734`.
  Its embedded metadata supplies the exact 14 class IDs and spellings frozen in
  `class_mapping.csv`.
- ATD-19 found no historical training image, annotation, split, permission, or
  leakage manifest. Its owner-reported validation metrics were influenced by
  model selection and cannot serve as an independent final test.
- Dataset owners' pages and licences support the dataset-level statements in
  the source ledger. None supplies verified per-image permission evidence for
  an AutoDentifyr corpus in this repository.

### Proposed protocol

Everything below describes required future collection, annotation, splitting,
freezing, and review. It is not evidence that any of those activities occurred.
Primary-source support and the boundary between source claims and project
inferences are documented in
[`phase_one_evaluation_corpus_sources.md`](phase_one_evaluation_corpus_sources.md).

### Unavailable evidence and authorization

- There is no authorized, access-controlled corpus location.
- No corpus source has item-level provenance and verified evaluation/storage
  permission in this session.
- No source images, canonical derivatives, counts, completed duplicate audit,
  split assignment, sealed final-test record, or immutable corpus manifest
  exists.
- No real Appraiser annotation, agreement measurement, adjudication, or release
  owner sample requirement exists.
- Corpus acquisition, owner/vendor contact, purchase, and Appraiser outreach
  were not authorized. These missing prerequisites block completion.

## Source and permission ledger

Keep dataset-level claims and per-image rights as separate rows. A dataset row
records what a publisher page or licence says about a named version. It never
clears an image. Each image admitted to a split needs an `item`-scope row that
binds its `item_id` to retained evidence for evaluation and storage, the
rightsholder or authorized licensor, required attribution, privacy/publicity
review, restrictions, verifier, verification time, and evidence hash. Add
separate claim rows when training, redistribution, publication, or derivative
creation needs a different grant.

The repository ledger deliberately contains only `dataset`-scope candidate
records marked `excluded`. Do not change eligibility to included until all
required item-level claims are verified and stored outside Git. A page-level
licence label, source availability, or a successful download is insufficient.

## Frozen raw-to-canonical mapping

`class_mapping.csv` is normative for Android class IDs 0 through 13. Preserve
each `raw_class` byte-for-byte, including `Rear-windscreen-Damage` and
`quaterpanel-dent`. The canonical representation separates damage type,
component family, and component position.

`Damage` in a raw class maps to `unspecified_visible_damage`; an Appraiser must
not force it to dent, crack, scratch, or another damage type without visible
evidence. A raw class may encode an inherent component family and, for names
such as front bumper or rear windscreen, only that explicit longitudinal
position. Generic door, fender, quarter-panel, running-board, and side-mirror
classes never establish left/right or front/rear identity. Required positions
must come from visible evidence, trustworthy capture metadata, or Appraiser
adjudication. `doorouter-dent` alone cannot become `left_front`.

## Annotation guidance

Create one annotation row per reviewable visible-damage region or explicit
surface assessment. Use stable pseudonymous `item_id`, `vehicle_id`,
`assessment_id`, and `session_id` values; never put VINs, plates, owner names,
or file-system locations in repository-safe manifests.

- Draw the tightest reproducible visible region in the declared coordinate
  format. Do not outline an entire component when only a smaller damaged region
  is visible. For diffuse or truncated damage, record ambiguity and the chosen
  boundary rule.
- Assign one `physical_defect_id` to the same physical defect across views.
  Give separate IDs to spatially distinct damage even when type and component
  match. If two views cannot be linked confidently, keep them separate and
  flag the ambiguity for adjudication.
- Record visibility as fully visible, partially visible, not visible, or
  unknown. Record whether the surface was inspected. A hidden, occluded,
  cropped, or uninspected surface is `unassessable`, never negative. Absence of
  an annotation is also not a negative.
- Use `out_of_scope` for visible damage outside the supported mapping and retain
  its observed description in `unsupported_damage_type`. Do not coerce it into
  a supported class. Use `unassessable` when blur, glare, darkness, occlusion,
  framing, or conflicting views prevent a defensible decision.
- A negative is allowed only for a fully visible, inspected surface under the
  frozen annotation guide. Record undamaged components on damaged Vehicles as
  explicit surface negatives; do not treat the Vehicle-level damage status as
  a component label.
- Record reflections, seams, dirt, water, glare, and other lookalikes as capture
  conditions and, when explicitly reviewed, negative or unassessable component
  observations. Do not relabel a real unsupported defect as undamaged.

At least two qualified reviewers should independently label the agreement
subset selected before review. Preserve each decision rather than overwriting
it. Route disagreement about region, physical-defect identity, damage type,
component, position, visibility, or scope to a qualified Appraiser. The
adjudication row records the pseudonymous reviewer, decision, time, guideline
version, disagreement codes, and rationale. Reviewer identity evidence and
qualifications remain access-controlled outside Git.

## Coverage and counts

The collection plan must include damaged and undamaged Vehicles; undamaged
components on damaged Vehicles; supported and out-of-scope visible damage;
passenger cars and light trucks; and reflections, seams, dirt, wet surfaces,
blur, low light, glare, and occlusion. Counts must distinguish images,
Vehicles, assessment/session groups, components, annotations, and unique
physical defects. Report each split separately and keep missing strata visible
as zero or unavailable rather than interpreting them as passed.

Populate `counts.csv` only from frozen records. Required strata are raw class,
canonical damage type, component family and position, annotation outcome,
condition, supported vehicle type, Vehicle damage status, and split. Record the
unit and denominator explicitly. Sample requirements remain unavailable until
the release-gate owner supplies intended error/uncertainty tolerances and an
Appraiser confirms the clinically relevant strata; do not invent a passing
sample size.

## Deduplication and split protocol

Perform deduplication before split allocation.

1. Hash original bytes and canonical derivatives separately with SHA-256.
   Group identical originals, re-encodes, crops, and other known derivatives by
   `original_asset_id` and exact hashes.
2. Run a versioned near-duplicate method over canonical images. Freeze its
   implementation, parameters, threshold, and candidate pairs. Have a reviewer
   resolve ambiguous pairs. A perceptual threshold is a protocol parameter, not
   proof of identity.
3. Group adjacent frames and overlapping clips from the same source video or
   burst before allocation. Preserve the source-video/burst ID and frame/time
   relation outside public manifests where privacy requires it.
4. Form allocation groups as the transitive closure of Vehicle,
   Intake-Assessment/session, original/derivative, near-duplicate, and adjacent-
   frame links. Assign every group to exactly one of `train`, `calibration`, or
   `final_test`. Desired balance never overrides group isolation.
5. Use train only for fitting. Use calibration for thresholds, score
   calibration, mapping, preprocessing, exclusions, and all selection/tuning.
   Freeze model, mapping, evaluator, preprocessing, thresholds, and calibration
   results before the final-test labels or results are opened.
6. Seal final test in access-controlled storage. Open it once for the declared
   final evaluation. Do not use its errors for selection or tuning. A later
   development cycle needs a newly versioned, still-sealed final set.

The leakage audit records exact-hash overlaps, shared Vehicles,
assessment/sessions, originals/derivatives, near-duplicate groups, adjacent-
frame groups, candidate-pair review, resolution, tool/version, reviewer, and
time. Completion requires zero unresolved cross-split findings; deleting a
record without documenting its disposition is not a clean audit.

## Package, hashes, and executable validation

An authorized corpus package uses `contract.json` and contains
`corpus_manifest.json` plus the seven tabular files named in
`required_files`. The manifest records schema/corpus versions, freeze time,
exact-byte serialization, hash algorithm, access-controlled location reference,
guideline and mapping versions, frozen model/preprocessing/evaluator/operating-
point and calibration identities, historical-manifest reconciliation,
selection freeze and final-test open times, confirmation-only final-test use,
and each file's relative path, byte length, role, and SHA-256.

Hash the exact committed or stored bytes without reserialization. Place the
manifest's own SHA-256 in a separately controlled `corpus_manifest.sha256`
record to avoid a self-referential digest. Immutability also requires storage
controls and retained version history; a checksum alone is not access control
or permission evidence.

Run the repository contract check:

```bash
python3 tool/phase_one_corpus_validator.py --repository-root .
```

After authorized evidence exists, validate a package without claiming the
completion gate:

```bash
python3 tool/phase_one_corpus_validator.py --package /approved/manifest/package
```

Use `--require-complete` only for the final Linear completion decision. It also
requires `corpus_manifest.sha256`, verified item permissions, populated
required strata, a completed zero-unresolved leakage audit, real Appraiser
adjudications, and selection freeze before final-test opening.

## Reconciliation with ATD-19

Every manifest must set
`historical_training_manifest_reconciliation=unavailable_per_ATD-19` unless
new authenticated historical records are separately recovered. That value
does not prove independence. Treat the historical training corpus as an
unknown-exposure set: compare candidate originals and near-duplicates against
any later recovered manifest before admission, record the audit, and exclude or
segregate unresolved matches. Public Roboflow split counts and the Colab folder
suffix must not be substituted for the missing training manifest.

## Current completion decision

Protocol, mapping, source-ledger, schema, and executable-validation work is
available. The required corpus location, item-level permissions, corpus rows,
counts, leakage audit, immutable manifest digest, and Appraiser evidence are
not. ATD-20 must therefore remain open for authorized human/data work.
