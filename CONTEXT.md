# AutoDentifyr

AutoDentifyr supports vehicle-damage assessment during intake at an independent collision repair shop. This glossary distinguishes the shop, the people involved, and the assessment artifacts they use.

## Language

**Repair Shop**:
The independent collision or body repair business that uses AutoDentifyr and owns the intake workflow.
_Avoid_: Customer, account

**Appraiser**:
A Repair Shop employee or estimator who performs and reviews an Intake Assessment.
_Avoid_: Technician, service advisor, end user

**Vehicle Owner**:
The person bringing a passenger car or light truck to the Repair Shop for assessment.
_Avoid_: Customer, user

**Appraiser Profile**:
A device-local, declared Appraiser identity selected for an Intake Assessment and attributed to assessment actions. It does not verify identity, and completed revisions preserve the author's name used at completion.
_Avoid_: Verified identity, account, login

**Vehicle**:
A persistent Repair Shop record for one passenger car or light truck. It has an internal identity, may carry confirmed identifiers such as VIN and licence plate, and may have multiple Intake Assessments. Each completed assessment preserves the vehicle details used for that revision.
_Avoid_: Assessment, Capture

**Vehicle Component**:
A position-specific physical exterior part of a Vehicle, such as the left-front door or right headlight. An Intake Assessment preserves the component identity used at the time. One Vehicle Component may have multiple Damage Findings when damage types or separately reviewable damaged areas differ.
_Avoid_: Generic part category, Damage Finding

**Intake Assessment**:
An in-person assessment of visible exterior collision and cosmetic damage for one Vehicle during one repair-shop intake event. It may span pauses and multiple capture sessions, but a later visit or materially different purpose creates another Intake Assessment. Its business state is Draft, Completed, or Voided.
_Avoid_: Inspection, scan, diagnosis

**Draft**:
The editable state of an Intake Assessment. Capture and review may occur in any order. Reopening a completed assessment returns it to Draft while preserving every completed Preliminary Damage Assessment revision.
_Avoid_: In progress, incomplete report

**Completed**:
The state of an Intake Assessment after the Appraiser has satisfied the Completion Gate and produced a Preliminary Damage Assessment revision.
_Avoid_: Final Repair Estimate, closed repair

**Voided**:
The state of an intentionally abandoned or invalidated Intake Assessment. The responsible Appraiser, time, and reason are recorded, and every completed revision remains in history with a visible void marker. A Voided assessment cannot be reopened; corrected work begins as a new Intake Assessment.
_Avoid_: Deleted, completed

**No Visible Damage Outcome**:
A completed Intake Assessment with no Confirmed Findings. It requires accepted Captures, review of every Proposed Finding, and the Appraiser's explicit confirmation that no supported visible exterior damage was found.
_Avoid_: Empty draft, failed detection

**Completion Gate**:
The conditions an Intake Assessment must meet before completion: a Vehicle and preserved vehicle-detail snapshot; at least one accepted Capture; a decision on every Proposed Finding; a Vehicle Component, Damage Type, and supporting evidence for every Confirmed Finding; review of the Assessment Estimate and its assumptions; review of every applicable Severity Assessment, uncertainty, and follow-up need; a reason for overriding any unmet evidence request; and Appraiser confirmation with author and completion time.
_Avoid_: Saving a draft, generating a preview

**Capture**:
An intentionally accepted still image belonging to an Intake Assessment. A captured camera frame and an imported image both become Captures when the Appraiser adds them; transient live-preview frames are not Captures.
_Avoid_: Live frame, preview frame

**Damage Observation**:
A model output associated with image evidence. Observations belonging to an accepted Capture are retained; observations from live-preview frames that never become a Capture are discarded. A Damage Observation does not itself represent the Appraiser's reviewed assessment.
_Avoid_: Damage Finding, confirmed damage

**Damage Finding**:
An editable assessment claim identifying one affected Vehicle Component and one Damage Type. It may be supported by observations from multiple Captures or added manually by the Appraiser. AutoDentifyr may suggest that matching observations support the same finding, but only the Appraiser confirms the merge. Its review state is Proposed, Confirmed, or Dismissed; completed revisions contain only Confirmed findings.
_Avoid_: Detection, bounding box

**Proposed Finding**:
A Damage Finding created from model observations and awaiting Appraiser review.
_Avoid_: Confirmed damage

**Confirmed Finding**:
A Damage Finding accepted or manually added by the Appraiser. It must have at least one supporting Capture. A manually added finding without a matching model observation also carries the Appraiser's note describing the visible evidence.
_Avoid_: Model detection, unreviewed suggestion

**Dismissed Finding**:
A Damage Finding rejected by the Appraiser and excluded from estimates and reports while remaining in correction history.
_Avoid_: Deleted observation

**Undetermined Finding Outcome**:
An explicit Appraiser decision that the available evidence cannot yet support confirming or dismissing a Proposed Finding. The Proposed Finding remains reviewable, and the outcome preserves conflicting-view flags, specific additional-view requests, and any reason for overriding an unmet request.
_Avoid_: Dismissed Finding, Confirmed Finding, Undetermined Severity

**Assessment Correction**:
An Appraiser action that accepts, rejects, edits, adds, merges, or splits a Damage Finding. The corrected finding governs the Draft assessment while the original model observations and the correction's author and time remain preserved.
_Avoid_: Rewritten model output, silent merge

**Assessment Estimate**:
The Intake Assessment's provisional estimate, composed from suggested Repair Operations and cost ranges supporting its Confirmed Findings. Shared repair work is counted once. It may be recalculated while the assessment is Draft. Completion freezes its values, inputs, and assumptions into a Preliminary Damage Assessment revision.
_Avoid_: Formal Repair Estimate, final quote

**Repair Operation**:
A suggested item of repair work addressing one or more Confirmed Findings. The Appraiser reviews its scope and cost range; work shared by several findings is represented once in the Assessment Estimate.
_Avoid_: Damage Finding, authorized repair

**Pricing Context**:
The confirmed Vehicle details, Repair Shop location, currency, labor rates, and parts assumptions used to determine an Assessment Estimate. It distinguishes vehicle-specific and regional pricing from a broader baseline.
_Avoid_: Currency conversion, vehicle identity

**Pricing Evidence Source**:
A versioned source of permitted price observations whose provenance, scope, and intended uses are explicit. A publisher claim, product demonstration, export capability, or placeholder amount is not itself a Pricing Evidence Source.
_Avoid_: Vendor marketing, price map, undocumented estimate

**Pricing Cohort**:
A defined group of comparable price observations sharing a Vehicle Component, Damage Type, Repair Operation, vehicle context, geography, currency, evidence type, inclusions, and exclusions. A raw detector class alone is not a Pricing Cohort.
_Avoid_: Detection class, generic price bucket

**Contextual Pricing Coverage**:
The set of Pricing Cohorts supported by permitted, versioned evidence for a confirmed Vehicle, applicable Repair Shop region, and country-specific currency. A provider capability or currency conversion does not establish coverage.
_Avoid_: Provider availability, converted baseline, marketing coverage

**Estimate Override**:
An Appraiser's recorded change to a suggested Repair Operation's scope, labor inputs, part choice, or cost range. It preserves the suggested values, the replacement values, and the change's author, time, and reason.
_Avoid_: Assessment Correction, refreshed pricing

**Partial Estimate**:
An Assessment Estimate with one or more Confirmed Findings lacking supported pricing. The missing pricing remains explicit and is never treated as zero cost. The Appraiser may complete the Intake Assessment after acknowledging the missing pricing, and the completed output remains visibly marked as a Partial Estimate.
_Avoid_: Complete price, zero-cost repair, No Visible Damage Outcome

**Severity Assessment**:
A conclusion attached to one Damage Finding describing visible damage extent as Minor, Moderate, Severe, or Undetermined using Damage Type-specific criteria, with supporting evidence, uncertainty, and follow-up needs. It is distinct from repair complexity and preserves Appraiser changes and their reasons alongside the original suggestion.
_Avoid_: Vehicle-wide severity score

**Severity Rubric**:
A versioned set of Damage Type-specific criteria, expert-reviewed examples, and boundary cases for assigning Minor, Moderate, Severe, or Undetermined to a Damage Finding by component-relative visible damage extent.
_Avoid_: Model threshold, repair-complexity scale, image-size rule

**Severity Ground Truth**:
The accepted finding-level Severity Assessment produced from rights-cleared evidence under an approved Severity Rubric, two independent Qualified Appraiser Reviewers, and designated-lead adjudication that preserves the original labels and disagreement.
_Avoid_: Image-level severity metadata, mask, model prediction, synthetic label

**Qualified Appraiser Reviewer**:
An Appraiser whose relevant assessment experience and rubric qualification have been independently verified for a severity review. Two reviewers label independently, and a separately designated qualified lead adjudicates disagreements.
_Avoid_: Simulated reviewer persona, unverified reviewer, model output

**Severity Evaluation Corpus**:
A versioned set of rights-cleared Damage Finding examples and Severity Ground Truth with source, Vehicle, incident, assessment/session, duplicate, and partition provenance sufficient for leakage-resistant evaluation.
_Avoid_: Image collection, detector training split, synthetic fixture set

**Severity Evidence Package**:
The access-controlled, checksummed collection of rubric, corpus, reviewer, annotation, evaluation, Android feasibility, and human acceptance records used to decide the Automated Severity Release Gate.
_Avoid_: Public research note, repository scaffold, model file

**Automated Severity Release Gate**:
The human decision that accepts a specific automated severity scope, model, and Android export only after qualified agreement, rights-cleared evaluation, calibration and abstention, end-to-end misses, representative physical-device feasibility, limitations, and manual or Undetermined fallback are reviewed.
_Avoid_: Research completion, synthetic validation, model export

**Undetermined Severity**:
A Severity Assessment whose available evidence does not support a severity level. It preserves the missing evidence and follow-up needs, including the Appraiser's reason when completing an assessment without the requested evidence.
_Avoid_: Minor damage, no damage, low detection confidence

**Preliminary Damage Assessment**:
The immutable, versioned AutoDentifyr output produced when an Appraiser completes an Intake Assessment after reviewing every Damage Finding and resolving required uncertainty. It preserves the accepted evidence and Vehicle details used at completion. Completing a reopened assessment creates a new revision so previously shared versions retain their original meaning.
_Avoid_: Quote, final estimate, repair authorization

**Report**:
A rendered or exported representation of one immutable Preliminary Damage Assessment revision, presented as an Appraiser detail view or a simpler Vehicle Owner view that preserves uncertainty and estimate limitations. Screen, PDF, and shared-image formats may present the same revision; changed assessment content requires a new revision.
_Avoid_: Editable assessment, independent report record

**Reopen**:
The explicit action that returns a completed Intake Assessment to an editable state. Completing it again produces a new Preliminary Damage Assessment revision.
_Avoid_: Silently edit a completed assessment

**Persistent Assessment Record**:
The Vehicle, Intake Assessment, accepted Captures, retained Damage Observations, Damage Findings, Appraiser corrections, and completed Preliminary Damage Assessment revisions kept after an assessment session. A Capture removed from a reopened draft remains part of any earlier immutable revision but is excluded from later revisions.
_Avoid_: Live-preview frame, discarded observation

**Formal Repair Estimate**:
The Repair Shop's reviewed and authoritative estimate of repair work and price, prepared after the Intake Assessment.
_Avoid_: Preliminary Damage Assessment, AI estimate

**Assessment Backup**:
A password-encrypted copy of all local assessment records and their supporting evidence, saved to an Appraiser-chosen location for restoration. It preserves assessment history and is distinct from a shared Report.
_Avoid_: Report export, shop sync

**Assessment Handoff**:
An explicit transfer of a Draft Intake Assessment to another Appraiser Profile on the same device, recording sender, recipient, and time. The receiving Appraiser confirms their profile before continuing, while earlier actions retain their original attribution.
_Avoid_: Device transfer, backup restore, authentication

**Permanent Deletion**:
The explicit removal of an entire Intake Assessment and its history, or a Vehicle and all its assessments, from the device. Unlike Voiding, it does not preserve that history and does not remove previously exported Reports or backups.
_Avoid_: Void, archive
