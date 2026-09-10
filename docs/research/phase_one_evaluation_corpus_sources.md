# Phase 1 evaluation-corpus primary-source notes

**Researched:** 2026-09-08 for ATD-20

**Scope:** Protocol evidence only. No corpus was accessed, downloaded, licensed,
or reviewed, and no legal conclusion is made here. These sources do not fill the
unavailable historical-training evidence recorded in
[`phase_one_model_provenance.md`](phase_one_model_provenance.md).

## Source and permission provenance

- The public Roboflow `Automobile Damage Detection` version 1 page currently
  identifies the project publisher, displays `CC BY 4.0`, reports 6,957 images
  and a 5,216/1,043/698 train/validation/test split, and records preprocessing.
  Those are dataset-page claims for that named version, not per-image rights
  records and not evidence that this version produced the historical training
  directory. [Roboflow version 1 dataset page](https://universe.roboflow.com/automobile-damage-detection/automobile-damage-detection/dataset/1)
- The CC BY 4.0 legal code says the grant covers only rights the licensor has
  authority to license, warns that use can remain restricted by other parties'
  rights, does not license patent or trademark rights, and does not generally
  license privacy, publicity, or similar personality rights. It also disclaims
  warranties of title and non-infringement. A project-level CC label therefore
  cannot substitute for item-level source, rightsholder, permission, privacy,
  publicity, and restriction evidence. [Creative Commons Attribution 4.0 legal code](https://creativecommons.org/licenses/by/4.0/legalcode.en)
- *Datasheets for Datasets* proposes recording dataset motivation, composition,
  collection process, and recommended uses to improve transparency and
  accountability. This supports a versioned corpus record that keeps source and
  collection evidence, annotation/adjudication process, intended use, known
  gaps, and restrictions together rather than reducing provenance to a license
  string. [Gebru et al., *Datasheets for Datasets*](https://arxiv.org/abs/1803.09010)
- W3C PROV defines provenance in terms of entities, activities, and agents and
  links such as derivation, attribution, and association. The ATD-20 ledger need
  not implement PROV, but stable IDs for each source item, canonical derivative,
  transformation, source assertion, and responsible reviewer preserve the same
  essential distinctions. [W3C PROV-DM](https://www.w3.org/TR/prov-dm/)

**Protocol implication:** keep a dataset/source-level ledger separate from the
per-image permission ledger. A candidate item is not rights-cleared merely
because its enclosing project advertises a license. Preserve the source URL and
version, asserted licensor/rightsholder, evidence URL or document ID, permitted
uses, attribution requirements, other-rights/privacy status, verification actor
and date, and unresolved constraints. Exclude unresolved items from every
executable split manifest.

## Grouped splitting and leakage

- Scikit-learn's official `GroupKFold` contract uses non-overlapping groups and
  directs callers to supply explicit domain-specific group labels. It provides
  direct precedent for treating a Vehicle/assessment/session as the allocation
  unit rather than independently allocating its images.
  [Scikit-learn `GroupKFold`](https://scikit-learn.org/stable/modules/generated/sklearn.model_selection.GroupKFold.html)
- Its `StratifiedGroupKFold` contract preserves class proportions only as far
  as possible while maintaining non-overlapping groups, and notes that exact
  stratification can be infeasible with a small number of large groups. Group
  isolation therefore takes precedence over desired balance, and actual
  per-class/per-condition counts must be reported rather than assumed.
  [Scikit-learn `StratifiedGroupKFold`](https://scikit-learn.org/stable/modules/generated/sklearn.model_selection.StratifiedGroupKFold.html)
- Google's official ML guidance uses training data for fitting, validation data
  for iterative decisions, and a test set only to confirm the selected model. It
  warns that repeated use makes validation and test sets “wear out” and requires
  test/validation examples not to duplicate training examples.
  [Google, *Datasets: Dividing the original dataset*](https://developers.google.com/machine-learning/crash-course/overfitting/dividing-datasets)
- Barz and Denzler found train/test near-duplicates in CIFAR-10 and CIFAR-100,
  explained that memorization can bias generalization comparisons, and observed
  a substantial accuracy drop after replacing duplicate test images. This is
  empirical evidence that byte-distinct near-duplicates can invalidate a held-
  out image evaluation, not merely reduce corpus variety.
  [Barz and Denzler, *Do We Train on Test Data?*](https://arxiv.org/abs/1902.00423)
- Ramos, Ramos, and Garcia distinguish identical-image (“hard”) from nearly
  identical-image (“soft”) leakage and report that both materially affect
  downstream evaluation. [Ramos et al., *Data Leakage in Visual Datasets*](https://openaccess.thecvf.com/content/ICCV2025W/Findings/html/Ramos_Data_Leakage_in_Visual_Datasets_ICCVW_2025_paper.html)
- The VCSL video-copy dataset keeps different source videos in train,
  validation, and test and describes their contents as independent. This is
  direct evidence for source-video isolation in that benchmark; applying the
  same boundary to adjacent frames from one assessment video is a conservative
  ATD-20 inference. [He et al., *A Large-scale Comprehensive Dataset and Copy-overlap Aware Evaluation Protocol for Segment-level Video Copy Detection*](https://openaccess.thecvf.com/content/CVPR2022/papers/He_A_Large-Scale_Comprehensive_Dataset_and_Copy-Overlap_Aware_Evaluation_Protocol_for_CVPR_2022_paper.pdf)

**Protocol implication:** assign all Captures for one Vehicle and Intake
Assessment/session group to exactly one of train, calibration, or sealed final
test. Before allocation, cluster originals, re-encodes/crops/derivatives,
near-duplicates, and adjacent video frames, then force each cluster into one
group and one split. The adjacent-frame rule is an application-specific
inference from the near-duplicate evidence: neighbouring frames commonly depict
the same physical scene even though their bytes differ. Record the exact-match
digest method, near-duplicate method/version/threshold, candidate pairs,
reviewed disposition, and cross-split overlap counts so the audit is
reproducible. A perceptual-match threshold is a documented protocol parameter,
not universal ground truth; ambiguous pairs require review.

## Calibration and sealed final evaluation

- Scikit-learn's official calibration guidance says a calibrator should ideally
  be fit on data independent of the classifier's training data because fitting
  on training outputs biases calibration. It explicitly makes the user
  responsible for disjoint data when calibrating an already-fitted estimator.
  [Scikit-learn, *Probability calibration*](https://scikit-learn.org/stable/modules/calibration.html)
- Google's three-way workflow reserves validation for model, feature, and
  hyperparameter decisions and test for final confirmation; using test results
  to guide repeated changes implicitly fits to the test set.
  [Google, *Datasets: Dividing the original dataset*](https://developers.google.com/machine-learning/crash-course/overfitting/dividing-datasets)

**Protocol implication:** threshold selection, score calibration, mapping
changes, preprocessing choices, error-driven exclusions, and every other
selection decision belong to train/calibration work. Freeze their versions and
hashes before unsealing final-test labels or results. Do not feed final-test
failures back into Phase 1 selection; any later revision needs a newly versioned
test protocol and a fresh, still-sealed evaluation set.

## Version and hash records

- NIST FIPS 180-4 specifies SHA-256 and explains that message digests detect
  whether bytes changed after the digest was generated.
  [NIST FIPS 180-4](https://csrc.nist.gov/pubs/fips/180-4/upd1/final)
- RFC 8785 explains that repeatable hashing of JSON requires an invariant
  serialization and defines one canonical JSON representation. It is an
  Informational RFC, not an Internet Standards Track specification.
  [RFC 8785, JSON Canonicalization Scheme](https://www.rfc-editor.org/rfc/rfc8785.html)

**Protocol implication:** record SHA-256 over the exact raw and canonical file
bytes, plus size and media type. Hash each frozen manifest as bytes after its
serialization convention is fixed; if JSON is used, either adopt and test a
named canonicalization such as RFC 8785 or hash the committed byte stream
without reserialization. A digest identifies content but does not by itself
provide access control, prove rights, or make storage immutable; those require
separate verified controls and evidence.

## Evidence boundaries for ATD-20

The sources justify protocol requirements, not completion evidence. They do not
establish an access-controlled corpus location, item-level permissions,
Appraiser labels or adjudication, populated stratum counts, immutable manifests,
or a completed leakage audit. Those facts can only be claimed after authorized
corpus assembly and recorded human review.
