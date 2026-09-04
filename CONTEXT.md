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

**Intake Assessment**:
An in-person assessment of visible exterior collision and cosmetic damage for one Vehicle during one repair-shop intake event. It may span pauses and multiple capture sessions, but a later visit or materially different purpose creates another Intake Assessment.
_Avoid_: Inspection, scan, diagnosis

**Capture**:
An intentionally accepted still image belonging to an Intake Assessment. A captured camera frame and an imported image both become Captures when the Appraiser adds them; transient live-preview frames are not Captures.
_Avoid_: Live frame, preview frame

**Damage Observation**:
Transient or retained model output tied to one Capture. It records what the model detected in that image and does not itself represent the Appraiser's reviewed assessment.
_Avoid_: Damage Finding, confirmed damage

**Damage Finding**:
An editable assessment claim identifying one affected Vehicle Component and one Damage Type. It may be supported by observations from multiple Captures or added manually by the Appraiser.
_Avoid_: Detection, bounding box

**Preliminary Damage Assessment**:
The versioned AutoDentifyr output produced when an Appraiser completes an Intake Assessment after reviewing every Damage Finding and resolving required uncertainty. Completing a reopened assessment creates a new revision so previously shared versions retain their original meaning.
_Avoid_: Quote, final estimate, repair authorization

**Reopen**:
The explicit action that returns a completed Intake Assessment to an editable state. Completing it again produces a new Preliminary Damage Assessment revision.
_Avoid_: Silently edit a completed assessment

**Formal Repair Estimate**:
The Repair Shop's reviewed and authoritative estimate of repair work and price, prepared after the Intake Assessment.
_Avoid_: Preliminary Damage Assessment, AI estimate
