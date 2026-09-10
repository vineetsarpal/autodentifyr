# Severity ground-truth and Android feasibility research refresh

**Issue:** ATD-25

**Access date for every web source:** 2026-09-09

**Scope:** Research and proposed protocol only; Android deployment only. iOS is
outside the active roadmap scope.

## Decision summary

ATD-25 cannot be completed from the evidence currently available in the
repository. There is no rights-cleared finding-level severity corpus, no
completed review by two independent qualified Appraisers and a designated
adjudication lead, no empirical candidate-model evaluation, no Android export
parity result, no representative physical-device measurement, and no human
release-gate acceptance.

The repository does support a precise future protocol. In that protocol,
**severity** remains a conclusion about **component-relative visible damage
extent** for one Damage Finding, not a vehicle-wide score, repair complexity,
repairability decision, or price proxy. Minor, Moderate, and Severe use the
pilot anchors **localized**, **intermediate**, and **widespread**. Those words
are only pilot anchors: qualified Appraisers must approve Damage Type-specific
boundaries and expert-reviewed examples before the rubric or any automation can
be released. Manual assessment and an explicit **Undetermined** outcome remain
available at every stage.

## Repository-safe evidence contract

The companion [`contract.json`](severity_evaluation/contract.json) versions the
public matrices and the 24-table future access-controlled evidence package.
[`severity_evidence_manifest.schema.json`](severity_evaluation/severity_evidence_manifest.schema.json)
uses JSON Schema draft 2020-12 and binds every package role to an exact relative
path, byte length, and SHA-256 digest. Hash the manifest's exact UTF-8 bytes in
a separately controlled `severity_evidence_manifest.sha256` record to avoid a
self-referential digest. A checksum establishes byte identity, not permission,
access control, reviewer qualification, or acceptance.

The public files deliberately contain no real examples, annotations, model
results, device measurements, or thresholds:

- [`evidence_status.csv`](severity_evaluation/evidence_status.csv) records all
  12 completion gates and their exact current blockers.
- [`source_permission_ledger.csv`](severity_evaluation/source_permission_ledger.csv)
  keeps candidate-source claims separate from item-level permission and excludes
  every unresolved source.
- [`rubric_coverage.csv`](severity_evaluation/rubric_coverage.csv) contains all
  14 Android classes crossed with the three pilot anchors while marking examples,
  boundaries, qualified review, and automation as unavailable.
- [`model_experiment_matrix.csv`](severity_evaluation/model_experiment_matrix.csv)
  freezes the required manual, simple, categorical, ordinal, and conditional
  segmentation comparisons without claiming they ran.
- [`android_feasibility_matrix.csv`](severity_evaluation/android_feasibility_matrix.csv)
  defines parity, cold/warm complete-pipeline latency, storage, peak memory, and
  sustained-behavior evidence while preserving every value as unavailable.

The public CLI validates both this repository state and a future authorized
package:

```bash
python3 tool/severity_evidence_validator.py --repository-root .
python3 tool/severity_evidence_validator.py --repository-root . \
  --package /approved/severity-evidence-package
python3 tool/severity_evidence_validator.py --repository-root . \
  --package /approved/severity-evidence-package --require-complete
```

Only the final command evaluates the real completion gates. Empty or synthetic
tables may validate structure, but cannot satisfy completion.

## Evidence classification

| Class | What is established for ATD-25 |
| --- | --- |
| **Verified fact** | The application vocabulary defines a Severity Assessment at Damage Finding level and retains Minor, Moderate, Severe, and Undetermined. The checked-in implementation currently returns `unsupported-severity-v1` and states that automated severity review is unsupported. The prior ATD-19 and ATD-20 notes record an unidentified historical training manifest and no rights-cleared evaluation corpus. These are repository facts, not performance evidence. |
| **Verified external fact** | CarDD's owner page describes 4,000 images and more than 9,000 instances across six damage categories for detection and segmentation; its licence form requires prior owner consent. The paper reports a separate per-image severity field but does not publish its scale or cutoffs in the paper text. VehiDE's papers describe 13,945 images, more than 32,000 instances, eight damage categories, and classification/detection/segmentation tasks; the 2023 paper also reports per-image severity without publishing a reproducible scale or cutoffs in the text. None of those statements establishes accepted AutoDentifyr finding-level Minor/Moderate/Severe labels. |
| **Proposed protocol** | The rubric, annotation workflow, grouped split, model comparison, calibration/abstention evaluation, export-parity check, Android benchmark design, and release gates below are requirements for future authorized work. They are not completed activities or measured results. |
| **Unavailable evidence** | Real eligible examples and labels; source/vehicle/incident grouping; reviewer qualification records; independent labels; disagreement and adjudication records; pilot results; final thresholds; trained candidate artifacts; accuracy, agreement, calibration, abstention, latency, memory, storage, sustained-use, or parity results; and human acceptance. |
| **Permission-required evidence** | CarDD requires prior PIC Lab consent, and no consent was sought. No item-level rights and privacy/publicity ledger was verified for CarDD, VehiDE, or another candidate source. Corpus acquisition, owner contact, terms acceptance, Appraiser recruitment, access-controlled storage, and physical-device testing require separate authorization. |
| **Synthetic-only evidence** | Synthetic images, records, reviewer personas, and fixtures may validate schemas, validators, disagreement routing, metric implementations, and failure gates. They cannot establish rights, expert agreement, ground truth, model accuracy, export parity on representative evidence, device feasibility, or release approval. |
| **Excluded evidence** | Image-level category labels, bounding boxes, and masks used as if they were accepted finding-level severity; owner-reported or validation-set model scores used as a sealed AutoDentifyr test; public dataset counts used as proof of usable rights; emulator or desktop timings used as representative Android results; model-only latency reported as complete-pipeline latency; simulated reviewers used as qualified Appraisers; repair cost or repair complexity used as severity; and any iOS result. |

## Primary-source findings and implications

### Candidate datasets do not supply the required ground truth

The [CarDD owner page](https://cardd-ustc.github.io/) says the dataset contains
4,000 high-resolution car-damage images and more than 9,000 annotated instances
in six damage categories and is designed for detection and segmentation. The
[CarDD paper](https://arxiv.org/abs/2211.00945) describes COCO-style instance
masks and boxes, rules for merging/splitting damage by class and component, a
100-image annotator test, and expert review of annotations. It also says an
accompanying spreadsheet contains image-level damage severity and shooting
angle, but the paper text does not disclose that field's ordinal scale,
observable cutoffs, or finding/component-relative interpretation. Its
[licensing form](https://cardd-ustc.github.io/docs/CarDD_license.pdf) says prior
PIC Lab consent is required even for research use and prior authorization is
required for commercial use and third-party transfer. No form was completed,
no owner was contacted, and no data was obtained.

The original [VehiDE paper](https://doi.org/10.1109/KSE59128.2023.10299490) and
the publisher's corrected follow-up
[article](https://doi.org/10.1080/24751839.2024.2367387) describe 13,945 images,
more than 32,000 instances, eight damage categories, and classification,
detection, and segmentation tasks. The original paper reports similar
annotation merge/split rules, a 100-image qualification test, expert review,
and a spreadsheet with image-level severity and shooting angle. It does not
publish a reproducible severity scale or cutoffs in the article text, and its
description of reviewer-team counts is internally inconsistent. Neither paper
describes the AutoDentifyr finding-level ordinal rubric or the required two
independent qualified Appraisers plus designated adjudication lead. The linked
corpus was not accessed, and the inspected publisher material did not establish
item-level rights for AutoDentifyr's intended storage, training, evaluation,
derivative, and release uses.

Therefore, a damage mask may be useful future evidence for visible area, but it
does not automatically identify one cross-view physical finding, the relevant
Vehicle Component, assessable component area, a Damage Type-specific boundary,
or an accepted severity. CarDD and VehiDE remain candidate source leads only.

### Ordinal prediction, calibration, and abstention need separate evaluation

Severity levels have order. The
[CORAL paper](https://doi.org/10.1016/j.patrec.2020.11.008) explains that
ordinary multiclass losses do not use label order and proposes rank-consistent
ordinal logits. This supports comparing an ordinal objective with a categorical
objective; it does not establish that CORAL or any other ordinal method wins on
AutoDentifyr evidence.

[Cohen's weighted-kappa paper](https://doi.org/10.1037/h0026256) introduced
scaled credit for disagreement, making a prespecified weighted agreement
summary relevant to ordered Appraiser labels. Kappa alone is not sufficient:
the protocol must also disclose the full disagreement matrix, class counts,
exact agreement, within-one agreement, and the direction of disagreements so a
rare Severe-to-Minor disagreement cannot disappear inside one aggregate.

[Guo et al.](https://proceedings.mlr.press/v70/guo17a.html) define confidence
calibration as agreement between predicted confidence and observed correctness,
show that modern neural networks may be miscalibrated, and evaluate temperature
scaling. Any calibrator and confidence threshold must be fit on the calibration
split only. Calibration error, negative log likelihood, a multiclass Brier
score, and reliability tables/diagrams should be reported by Damage Type and in
aggregate; binning and weighting conventions must be frozen because a single
calibration number is convention-dependent.

[Geifman and El-Yaniv](https://papers.neurips.cc/paper/2017/hash/4a8423d5e91fda00bb7e46540e2b0cf1-Abstract.html)
describe selective classification as trading coverage for risk. AutoDentifyr
should report the entire prespecified risk-coverage curve plus fixed operating
points selected on calibration data. An automation abstention is not a Minor
label and is not identical to an Appraiser's Undetermined conclusion: it routes
the finding to manual review, where the Appraiser may select any supported
outcome, including Undetermined when the evidence remains insufficient.

### Mobile feasibility is empirical and pipeline-specific

The original
[MobileNetV2 paper](https://openaccess.thecvf.com/content_cvpr_2018/html/Sandler_MobileNetV2_Inverted_Residuals_CVPR_2018_paper.html)
evaluates accuracy, multiply-adds, parameter count, and actual latency. It is
support for treating a MobileNet-family model as a mobile-oriented candidate,
not proof that one meets AutoDentifyr's device or accuracy gate.

Google's official
[LiteRT performance-measurement guide](https://github.com/tensorflow/tensorflow/blob/master/tensorflow/lite/g3doc/performance/measurement.md)
says its benchmark tools measure initialization, warm-up and steady-state
inference time and memory, supports delegate comparisons, and warns that a
native shell binary can differ from an actual foreground Android app. Even the
Android benchmark app measures the model runtime rather than AutoDentifyr's
complete camera-to-reviewed-result path. It is suitable for operator/delegate
diagnosis, while the release gate requires instrumentation in the real app.

Android's
[performance-measurement guidance](https://developer.android.com/topic/performance/measuring-performance)
says not to measure a debug build, recommends a production-like/profileable
configuration, and notes material device and run-to-run variation. The
[Macrobenchmark guide](https://developer.android.com/topic/performance/benchmarking/macrobenchmark-overview)
provides repeated end-user-flow measurement and system traces and discourages
emulator numbers as representative of user devices. These sources support a
release-like physical-device protocol; they supply no AutoDentifyr numbers.

Android's current
[NNAPI migration guide](https://developer.android.com/ndk/guides/neuralnetworks/migration-guide)
says NNAPI was deprecated in Android 15 and directs machine-learning workloads
toward frameworks such as LiteRT. LiteRT's official
[delegate guidance](https://ai.google.dev/edge/litert/performance/delegates)
explains that delegate support depends on the model and device and recommends
benchmarking. A new release plan should therefore record CPU/GPU/other supported
delegate behavior and fallback for each device instead of assuming an
NNAPI-first implementation or universal acceleration.

TensorFlow's official
[post-training quantization guide](https://www.tensorflow.org/model_optimization/guide/quantization/post_training)
describes size/latency/resource trade-offs and requires representative data for
full-integer activation calibration. It does not guarantee retained task
accuracy. Every exported/quantized variant therefore needs both source-to-LiteRT
parity evaluation and the same sealed task evaluation as the source candidate.

## Proposed ground-truth protocol

### 1. Freeze the rubric and unit of judgment

The annotation unit is a **Damage Finding**: one physical defect of one Damage
Type on one position-specific Vehicle Component, potentially supported by
multiple Captures. Do not annotate severity independently per image and then
silently treat those labels as finding truth.

For each finding, reviewers see only authorized evidence and record:

- the assessable visible portion of the component and all supporting views;
- the visible damaged region, including any boundary ambiguity;
- visibility, truncation, occlusion, glare, blur, and conflicting-view flags;
- the component-relative visible extent rationale;
- Minor/localized, Moderate/intermediate, Severe/widespread, or Undetermined;
- missing evidence and a specific requested view when Undetermined; and
- the rubric and pilot-anchor version used.

Component-relative extent may use a mask-derived area ratio as a reproducible
supporting measurement only when both the damage and assessable component masks
are qualified. It is not a universal threshold and must not replace Appraiser
judgment. Perspective, curvature, occlusion, diffuse damage, multiple views,
and Damage Type-specific morphology can change the meaning of the same 2-D
ratio. Severity also must not be inferred from price, repair operation, safety
consequence, or repair complexity.

Before the main review, the designated adjudication lead conducts a rights-
cleared pilot with boundary cases for every in-scope Damage Type. The pilot must
produce expert-reviewed examples for localized/intermediate/widespread and
counterexamples or Undetermined cases. Revise and version the rubric until the
qualified reviewers and release owner explicitly accept its examples and
boundaries. A pilot revision invalidates labels made under an older rubric
unless they are re-reviewed or explicitly reconciled.

### 2. Qualify reviewers and preserve independence

Use exactly two independent qualified Appraisers for the first-pass label of
every agreement item, plus a separately designated qualified adjudication lead.
The access-controlled qualification record must state the qualification
criteria accepted by the project, issuer/employer or experience evidence,
relevant jurisdiction and expiry where applicable, relevant vehicle-damage
assessment experience, conflict-of-interest declaration, rubric training and
pilot completion, verifier, verification time, and evidence-document hashes.
The public record contains pseudonymous reviewer IDs and qualification status,
not personal documents.

The two reviewers work independently and cannot see each other's label,
rationale, confidence, or discussion before submission. Preserve both original
records immutably. Route any difference in severity, finding identity,
component, Damage Type, assessability, or evidence sufficiency to the
adjudication lead. Adjudication adds a new reasoned decision; it never overwrites
the originals. An unresolved case remains Undetermined/unresolved and is
ineligible as automated-training or final-test ground truth.

Agreement is a property of the independent pre-adjudication labels. Report the
ordinal confusion matrix, exact and within-one agreement, prespecified weighted
kappa with confidence interval, disagreement directions, and per-Damage-Type
counts. Do not apply a generic adjective such as “good agreement” or invent a
passing value. The release owner and qualified Appraisers must set minimums and
the required sample before labels are opened.

### 3. Establish rights and leakage-resistant partitions

Every included item needs a verified item-level ledger covering provenance,
rightsholder or authorized licensor, intended evaluation/training/storage and
derivative uses, retention, attribution, privacy/publicity review, restrictions,
verification actor/time, and retained evidence hash. A dataset-page licence or
successful access is not an item-level permission record.

Preserve stable pseudonymous identifiers for source asset, derivative, Vehicle,
incident, Intake Assessment/session, physical finding, component, and all
Capture views. Before allocation, cluster exact copies, re-encodes, crops,
near-duplicates, burst/adjacent frames, the same Vehicle, and the same incident
or assessment. Assign the transitive closure of those relations to exactly one
of `train`, `calibration`, or sealed `final_test`. Group isolation takes
precedence over stratification. Reconcile every source against any later
recovered historical-training manifest; unresolved exposure makes the item
ineligible for the final test.

Use train only for fitting. Use calibration for model selection, rubric-to-label
mapping, preprocessing, segmentation decisions, quantization calibration,
probability calibration, abstention thresholds, and every operating point.
Freeze all artifacts and decisions before opening final-test labels/results.
Final-test errors cannot drive another selection cycle.

## Proposed candidate and evaluation protocol

### Candidate matrix

Compare at least:

1. non-learned priors (majority-by-Damage-Type and, if qualified masks exist, a
   calibration-only visible-extent rule);
2. a small shallow crop classifier as a simpler learned baseline;
3. MobileNet-family component/finding crop classifiers at prespecified capacity
   and input-size points;
4. the same appropriate backbone comparison under categorical cross-entropy
   and an ordinal objective such as cumulative/rank-consistent logits; and
5. only if separately measured, a segmentation-assisted variant.

Every identity includes source revision, architecture/configuration, weights
hash, training code/environment, input and preprocessing contract, label/rubric
version, split-manifest hashes, objective, seed, optimizer schedule, selection
metric, calibrator, abstention rule, export command/runtime, and exact Android
artifact hash. Parameter count, operations, and artifact bytes are descriptors,
not substitutes for accuracy or device measurement.

Segmentation is conditional. Add it only when a frozen ablation shows a
prespecified, human-accepted benefit over crop/component classification that is
large enough to justify its additional annotation burden, latency, memory,
storage, export risk, and pipeline complexity. Otherwise retain the simpler
classifier.

### Evaluation outputs

Report raw counts and confidence intervals, never only one aggregate:

- the full ordered 3-by-3 automated confusion matrix on adjudicated determinate
  ground truth, ordinal absolute error, exact and within-one accuracy, and every
  one-step and two-step overcall/undercall;
- recall and undercall rate for Severe, because a Severe-to-Minor error must
  remain visible;
- all metrics by Damage Type, component family, capture condition, and other
  prespecified coverage strata, with unavailable or too-small cells explicit;
- negative log likelihood, multiclass Brier score, frozen-bin reliability
  tables/diagrams and calibration error before and after calibration;
- risk, error severity, and stratum coverage across the full abstention curve
  and at calibration-selected operating points;
- conflicting-view behavior and the rate at which those findings are correctly
  routed to manual review; and
- end-to-end detection-miss accounting. Every eligible ground-truth finding is
  in the denominator even when the upstream detector produces no usable crop.
  Also report severity-on-oracle-crop separately so detection and severity
  failures are distinguishable.

An automated output may suggest Minor, Moderate, or Severe or abstain. It may
not erase the Appraiser's ability to assess manually or record Undetermined.

## Proposed Android-only feasibility protocol

### Export parity before performance

For the exact frozen final candidate and each LiteRT variant, run identical
rights-cleared inputs through the source and Android artifacts with frozen
pre/postprocessing. Record tensor-level tolerances chosen before evaluation,
per-example class/score differences, severity decisions, abstentions, and
aggregate task-metric deltas. Fail closed on unsupported operations, unexpected
delegate fallback, non-finite output, preprocessing drift, or a parity gate not
accepted by the release owner. Synthetic inputs can test plumbing but cannot
satisfy representative parity.

### Physical-device matrix and complete path

The release owner must approve a representative physical Android matrix that
covers supported OS/API levels and low/middle/high resource tiers, including the
actual CPU/accelerator families in scope. Pin device model, SoC, RAM, ABI, OS
build, app/model/runtime versions, delegate and thread settings, power mode,
battery state, ambient/start temperature, and whether the observed graph was
fully delegated or fell back.

Use a non-debuggable, production-like, profileable build. Instrument the real
foreground workflow from accepted image bytes to displayed severity suggestion
or abstention, including decode, orientation, crop/component selection, resize,
normalization, tensor transfer, interpreter/delegate initialization, inference,
postprocessing, calibration, and UI handoff. Report model-only LiteRT benchmark
results separately for diagnosis.

Define and preserve:

- **cold complete-pipeline latency:** process/interpreter/delegate not resident,
  with cache and compilation state explicitly controlled and recorded;
- **warm complete-pipeline latency:** initialized pipeline after a fixed,
  recorded warm-up sequence;
- per-stage and end-to-end p50/p90/p95/p99, minimum/maximum, iteration count,
  failures, timeouts, and raw iteration records rather than an average alone;
- packaged model bytes, installed-app size delta, writable/runtime cache delta,
  and any downloaded bytes (the active design should require none unless a
  separately approved contract says otherwise);
- baseline, initialization, first-run, steady and peak process memory with the
  collection tool/version and sampling limits; and
- a sustained, production-representative cadence long enough to reveal thermal
  or resource degradation, reporting latency over time, temperature/thermal
  status, memory trend, failures, battery conditions, and throttling. Duration,
  cadence, cool-down, and acceptance limits must be approved before testing.

Do not report emulator, desktop, native-shell, or model-only figures as the app
gate. Do not compare delegates across different devices as if hardware were
controlled. All proposed acceptance thresholds remain unavailable until the
product/release owner and qualified Appraisers approve user-journey and safety
requirements.

## Human release gate and exact blockers

Automation remains unsupported until one versioned release record contains:

1. a rights-cleared, access-controlled evidence package and independently
   verified manifest/checksums;
2. an accepted Damage Type-specific rubric with qualified pilot anchors;
3. verified qualifications for two independent Appraisers and the designated
   adjudication lead;
4. preserved independent labels, disagreement metrics, adjudications, and
   human acceptance against thresholds fixed before review;
5. leakage-audited train/calibration/sealed-final partitions and historical-
   exposure reconciliation;
6. frozen baseline and MobileNet-family candidate results for categorical and
   ordinal objectives, with conditional segmentation justified or rejected by
   measured ablation;
7. calibration, abstention, conflicting-view, per-type coverage, and end-to-end
   detector-miss results accepted by the named human gate owners;
8. source-to-LiteRT parity for the exact shipped artifact;
9. cold/warm complete-pipeline latency, storage, peak memory, delegate behavior,
   and sustained results on the approved representative physical Android
   matrix; and
10. explicit product/release-owner and qualified-Appraiser approval, with
    signatures/identities retained in the controlled evidence system.

None of these real-evidence gates is satisfied by this research refresh.
Until they are, keep `UnavailableSeveritySuggestionSource`, manual Appraiser
assessment, and Undetermined behavior as the supported product path.

## Validator test-first record

The validator was developed through the public CLI/package seam with synthetic
temporary fixtures only. The red/green progression was recorded on 2026-09-09:

1. Repository-contract CLI test: red because
   `tool/severity_evidence_validator.py` did not exist; green after the CLI and
   explicit unavailable public matrices were added.
2. Package-structure test: red because `validate_evidence_package` did not
   exist; green after exact roles, paths, columns, byte lengths, and checksums
   were validated.
3. Group-partition test: red because a shared incident could cross train and
   final test; green after all Vehicle, incident, assessment/session, original,
   near-duplicate, adjacent-frame, and allocation groups were isolated.
4. Synthetic-review test: red because completion emitted no specific synthetic
   reviewer or label error; green after synthetic personas and annotations were
   excluded from qualified review and ground truth.
5. Disagreement test: red because an incorrect Minor-to-Severe ordinal distance
   and a non-lead adjudicator were accepted; green after original-label,
   ordinal-distance, and designated-lead checks were added.
6. Rights test: red because a dataset-scope unverified record could accompany
   an example; green after verified item-level evaluation, storage, privacy,
   provenance, evidence-hash, and unresolved-constraint checks were added.
7. Final-test independence test: red because final test could be opened before
   selection freeze; green after ordered ISO-8601 timestamp validation.

This progression demonstrates validator behavior only. It supplies no corpus,
expert agreement, accuracy, parity, device feasibility, or release evidence.

## Sources

All sources below were accessed 2026-09-09. Primary owner, publisher,
proceedings, standards, and official platform documentation were preferred.

- CarDD owners, [project and dataset description](https://cardd-ustc.github.io/).
- Wang, Li, and Wu, [*CarDD: A New Dataset for Vision-Based Car Damage Detection*](https://arxiv.org/abs/2211.00945), IEEE Transactions on Intelligent Transportation Systems 24(7), 2023; DOI [10.1109/TITS.2023.3258480](https://doi.org/10.1109/TITS.2023.3258480).
- PIC Lab, [CarDD dataset licensing form](https://cardd-ustc.github.io/docs/CarDD_license.pdf).
- Huynh et al., [*VehiDE Dataset: New dataset for Automatic vehicle damage detection in Car insurance*](https://doi.org/10.1109/KSE59128.2023.10299490), KSE 2023.
- Hoang et al., [*Powering AI-driven car damage identification based on VeHIDE dataset*](https://doi.org/10.1080/24751839.2024.2367387), Journal of Information and Telecommunication 9(1), 2025 (publisher page notes a correction).
- Sandler et al., [*MobileNetV2: Inverted Residuals and Linear Bottlenecks*](https://openaccess.thecvf.com/content_cvpr_2018/html/Sandler_MobileNetV2_Inverted_Residuals_CVPR_2018_paper.html), CVPR 2018.
- Cao, Mirjalili, and Raschka, [*Rank consistent ordinal regression for neural networks with application to age estimation*](https://doi.org/10.1016/j.patrec.2020.11.008), Pattern Recognition Letters 140, 2020.
- Cohen, [*Weighted kappa: Nominal scale agreement with provision for scaled disagreement or partial credit*](https://doi.org/10.1037/h0026256), Psychological Bulletin 70(4), 1968.
- Guo et al., [*On Calibration of Modern Neural Networks*](https://proceedings.mlr.press/v70/guo17a.html), ICML 2017.
- Geifman and El-Yaniv, [*Selective Classification for Deep Neural Networks*](https://papers.neurips.cc/paper/2017/hash/4a8423d5e91fda00bb7e46540e2b0cf1-Abstract.html), NeurIPS 2017.
- Google TensorFlow, [LiteRT performance measurement](https://github.com/tensorflow/tensorflow/blob/master/tensorflow/lite/g3doc/performance/measurement.md).
- Android Developers, [Overview of measuring app performance](https://developer.android.com/topic/performance/measuring-performance).
- Android Developers, [Write a Macrobenchmark](https://developer.android.com/topic/performance/benchmarking/macrobenchmark-overview).
- Android Developers, [NNAPI migration guide](https://developer.android.com/ndk/guides/neuralnetworks/migration-guide).
- Google AI Edge, [LiteRT delegates](https://ai.google.dev/edge/litert/performance/delegates).
- TensorFlow Model Optimization, [Post-training quantization](https://www.tensorflow.org/model_optimization/guide/quantization/post_training).
- Google Machine Learning, [Dividing the original dataset](https://developers.google.com/machine-learning/crash-course/overfitting/dividing-datasets).
- Scikit-learn, [GroupKFold](https://scikit-learn.org/stable/modules/generated/sklearn.model_selection.GroupKFold.html) and [StratifiedGroupKFold](https://scikit-learn.org/stable/modules/generated/sklearn.model_selection.StratifiedGroupKFold.html).
- NIST, [FIPS 180-4 Secure Hash Standard](https://csrc.nist.gov/pubs/fips/180-4/upd1/final).
