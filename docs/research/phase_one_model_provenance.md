# Phase 1 model, dataset, and Android export provenance

**Manifest version:** 1

**Frozen:** 2026-09-08 for ATD-19

**Scope:** Android object detection only. iOS/Core ML is explicitly out of scope.

**Application source:** Git commit
`8b51f69319001f509584bef174ac8163dc15248d`; pre-existing uncommitted ATD-31
work is intentionally not part of this manifest's version identity.

This manifest distinguishes verified evidence, reconstruction, and unavailable
lineage. It does not grant or interpret legal rights.

**No credentials, source images, or new model binaries are committed.**

## Frozen artifacts

| Artifact | Frozen identity | Status |
| --- | --- | --- |
| Owner model repository | [`vineetsarpal/yolov11n-car-damage` at `ad93b6cbb6f1e14a385945c43cd36cf700385c86`](https://huggingface.co/vineetsarpal/yolov11n-car-damage/tree/ad93b6cbb6f1e14a385945c43cd36cf700385c86) | Verified repository snapshot. It contains only `.gitattributes`, `README.md`, `args.yaml`, `best.pt`, `confusion_matrix_normalized.png`, and `results.png`. |
| Source checkpoint | `best.pt`, 5,476,762 bytes, SHA-256 `cf3e55e63fd4564f68f78782be4e2608d26054753ba90762ab101dd22cdec962` | Verified from the [revision-pinned checkpoint record](https://huggingface.co/vineetsarpal/yolov11n-car-damage/blob/ad93b6cbb6f1e14a385945c43cd36cf700385c86/best.pt). It was introduced by [`9f49ada03638abfa61ef21c2148ab1600c263e2b`](https://huggingface.co/vineetsarpal/yolov11n-car-damage/commit/9f49ada03638abfa61ef21c2148ab1600c263e2b), and its [file history](https://huggingface.co/vineetsarpal/yolov11n-car-damage/commits/ad93b6cbb6f1e14a385945c43cd36cf700385c86/best.pt) shows no later change through the frozen snapshot. |
| Android export | [`android/app/src/main/assets/best.tflite`](../../android/app/src/main/assets/best.tflite), 5,372,822 bytes, SHA-256 `56d8341be346bbc9ebe94a038405b5f5f3ef7fd172ffb3fb99e2ac0e38cb8734` | Verified locally with `shasum -a 256`. The file is intentionally excluded by [`**/*.tflite`](../../.gitignore), so Git has no revision history for it. Its relationship to the source checkpoint is reconstructed, not proven: the owner repository has no TFLite artifact, export log, or checksum mapping. |

The owner repository names `Ultralytics/YOLO11` and `yolo11n.pt` but does not
pin the upstream base checkpoint by revision or checksum. That base lineage is
therefore unavailable.

## Training and evaluation lineage

The [revision-pinned owner card](https://huggingface.co/vineetsarpal/yolov11n-car-damage/blob/ad93b6cbb6f1e14a385945c43cd36cf700385c86/README.md)
says that a YOLO11n detector was trained at 640 x 640 on approximately 6,900
Roboflow Automobile Damage Detection images with 14 bounding-box categories.
The retained [training arguments](https://huggingface.co/vineetsarpal/yolov11n-car-damage/blob/ad93b6cbb6f1e14a385945c43cd36cf700385c86/args.yaml)
record:

- `model=yolo11n.pt`, `data=/content/Automobile-Damage-Detection-4/data.yaml`,
  `epochs=50`, `patience=10`, `batch=16`, `imgsz=640`, `device=0`,
  `pretrained=true`, `optimizer=auto`, `seed=0`, `deterministic=true`,
  `fraction=1.0`, `amp=true`, `val=true`, and `split=val`;
- learning settings `lr0=0.01`, `lrf=0.01`, `momentum=0.937`,
  `weight_decay=0.0005`, `box=7.5`, `cls=0.5`, and `dfl=1.5`; and
- on-the-fly augmentation settings including `hsv_h=0.015`, `hsv_s=0.7`,
  `hsv_v=0.4`, `translate=0.1`, `scale=0.5`, `fliplr=0.5`, `mosaic=1.0`,
  and `close_mosaic=10`.

The card presents the values as self-reported training metrics but does not bind
them to an immutable image manifest. The retained arguments say `val=true` and
`split=val`. Consequently, the best supported interpretation is:

| Data | Known influence |
| --- | --- |
| Training split | Influenced learned weights. Exact image IDs, annotations, and hashes are unavailable. |
| Validation split | The probable source of the owner-reported metrics, but the missing results files prevent a checkpoint-to-metric binding. It influenced training/selection because validation was enabled and `patience=10` configured early stopping. Ultralytics documents `patience` as waiting for improvement in validation metrics and `split=val` as selecting the validation split ([training](https://docs.ultralytics.com/modes/train/), [validation](https://docs.ultralytics.com/modes/val/)). The exact validation manifest, best epoch, and fitness trace are unavailable. |
| Test split | A test split exists on candidate public Roboflow versions, but there is no retained evidence that this checkpoint was evaluated on it or that it remained untouched during experimentation. No test result is claimed. |

The card's **AP50 0.797** and **AP50:95 0.552** are owner-reported metrics;
`split=val` supports, but does not prove, that they came from the retained
run's validation split. They have not been reproduced by AutoDentifyr and are
not application accuracy, release-gate, or physical-device results.

Roboflow currently attributes the public project to `Automobile Damage
Detection`, labels it CC BY 4.0, and lists 6,957 images. Its versioned public
[`/1`](https://universe.roboflow.com/automobile-damage-detection/automobile-damage-detection/dataset/1)
page reports 5,216 train, 1,043 validation, and 698 test images, with
auto-orientation and fit-with-padding to 640 x 640; the project's
[`/3` model record](https://universe.roboflow.com/automobile-damage-detection/automobile-damage-detection/model/3)
also reports training on 6,957 project images.
These are candidate context only. **Do not assume that
`/content/Automobile-Damage-Detection-4/data.yaml` corresponds to public Roboflow
export `/1` or `/3`.** The folder suffix does not prove any Roboflow version;
even the similarly numbered public [`/4`](https://universe.roboflow.com/automobile-damage-detection/automobile-damage-detection/dataset/4)
is only a candidate correlation. The actual `data.yaml` was not retained.

### Explicitly unavailable evidence and access constraints

- No training `data.yaml`, source-image or annotation manifest, image IDs,
  hashes, split-generation record, duplicate/leakage audit, or permission
  ledger is present in the owner model repository or AutoDentifyr repository.
- No training code/environment lock, Ultralytics training version, dependency
  versions, full logs, results CSV, best-epoch/fitness trace, tuning history, or
  evidence binding the card metrics to the frozen checkpoint is retained.
- No evidence shows whether public Roboflow `/1`, `/3`, `/4`, another export,
  or locally modified data populated the Colab directory. Public split counts
  therefore cannot be assigned to the training run.
- No independent final-test or rights-cleared application accuracy evaluation
  is available. The public corpus was not acquired for this work; doing so may
  require accepting Roboflow access/terms, and the task expressly forbids
  acquiring corpora or contacting owners/vendors.
- No export notebook/log, original TFLite checksum record, conversion
  dependency lock, or signed attestation links `best.pt` to local `best.tflite`.

### Clean holdout proposal

Because the original evaluation lineage cannot be recovered, do not use the
owner-reported validation scores as a Phase 1 gate. Under the ATD-14/ATD-20
protocol, later authorized work should:

1. Assemble a rights-cleared corpus independently of the unrecoverable training
   export; deduplicate originals, near-duplicates, and adjacent video frames
   before splitting by Vehicle and assessment/session.
2. Freeze independent train, calibration, and final-test sets. Freeze model,
   thresholds, mappings, and all tuning on calibration data before opening the
   final test; never use final-test outcomes for selection.
3. Use Appraiser-adjudicated damage-to-position-specific-component annotations,
   retain raw 14-class spellings, stable physical-defect IDs across views, and
   ambiguity/visibility flags. Hidden or uninspected surfaces are not negatives.
4. Include damaged and undamaged Vehicles/components, out-of-scope damage, and
   representative reflections, seams, dirt, wet surfaces, blur, low light,
   glare, occlusion, and other capture-condition variation.
5. Freeze version/hash manifests, permission ledger, annotation guide, label
   mapping, leakage audit, adjudication record, and per-class/per-condition
   counts. Report COCO and per-class AP separately from operating-point
   precision/recall, negative-image false alerts, component-assignment errors,
   uncertainty, and coverage gaps.

This is a proposal only; this checkpoint task did not acquire data, label
images, contact Appraisers, tune thresholds, or perform device testing.

## Android tensor and inference contract

Direct FlatBuffer inspection of the frozen local file and its appended
`metadata.json` established:

| Contract item | Verified value |
| --- | --- |
| Task | Object detection; batch 1; stride 32; 3 channels |
| Input | Tensor `images`, float32, NHWC `[1, 640, 640, 3]` |
| Output | Tensor `Identity`, float32, `[1, 18, 8400]`: feature-major candidates comprising 4 box values plus 14 class scores; NMS is not embedded (`nms=false`) |
| Export precision | Float32 input/output. Embedded metadata claims `half=false`, `int8=false`, but repository-history graph inspection found 180 float16 constants and 180 `DEQUANTIZE` operations. The metadata precision flag is therefore misleading; the artifact stores float16 weights with float32 I/O. |
| Metadata exporter | Ultralytics `8.4.7`; metadata timestamp `2026-01-22T03:05:15.005807` |

Android loads `best.tflite` as a detection model via
[`ModelType.detect`](../../lib/models/models.dart), materializes the bundled
asset to an absolute app-files path in
[`MainActivity.kt`](../../android/app/src/main/kotlin/com/vineetsarpal/autodentifyr/MainActivity.kt),
and invokes the locked `ultralytics_yolo` `0.6.14` package recorded in
[`pubspec.lock`](../../pubspec.lock).

At runtime, the package applies camera orientation, letterboxes without
cropping to 640 x 640 using black padding, packs RGB in NHWC order, and
normalizes each channel as `value / 255`. It selects the highest class score
for each candidate strictly above the confidence threshold, converts
center-`x,y,width,height` boxes to corners, sorts by score, applies
class-agnostic runtime NMS (suppression when IoU is strictly greater than the
threshold), caps results, and maps boxes back through the letterbox transform.
Camera mode configures confidence `0.5`, IoU `0.5`, and at most 20 results in
[`camera_inference_controller.dart`](../../lib/presentation/controllers/camera_inference_controller.dart).
The single-image/evidence path does not override package defaults: confidence
`0.25`, IoU `0.7`, and at most 30 results. These behaviors are verified from
the locally locked package source; the package's public API documents the
default thresholds ([Ultralytics Flutter API](https://github.com/ultralytics/yolo-flutter-app/blob/main/doc/api.md)).

### Android class-ID order

The numeric mapping below is verified from the TFLite's embedded metadata; the
ordered prose list in the model card alone is not treated as an ID mapping.

| ID | Class | ID | Class |
| ---: | --- | ---: | --- |
| 0 | `Front-windscreen-damage` | 7 | `boot-dent` |
| 1 | `Headlight-damage` | 8 | `doorouter-dent` |
| 2 | `Rear-windscreen-Damage` | 9 | `fender-dent` |
| 3 | `Runningboard-Damage` | 10 | `front-bumper-dent` |
| 4 | `Sidemirror-Damage` | 11 | `quaterpanel-dent` |
| 5 | `Taillight-Damage` | 12 | `rear-bumper-dent` |
| 6 | `bonnet-dent` | 13 | `roof-dent` |

## Export record

The original export command and environment are unavailable. The
`format=torchscript` value in training `args.yaml` is a serialized
training/default argument and is **not** proof of the Android export command.

Local repository commit `cc00bd97011ee6f9dbc292fa5876fc31ab7564a0`
(`git show cc00bd9`) records a controlled reconstruction from the
checksum-verified checkpoint. It found that `half=True` recreated the app
artifact's 180 float16 constants and operator inventory; the reconstructed and
app artifacts produced bit-identical output for one deterministic synthetic
linear-ramp input. This is verified reconstruction evidence, not proof of the
unknown original command and not an accuracy test. The reconstructed file was
not committed and is not introduced by this manifest.

Verified reconstruction call:

```python
from ultralytics import YOLO

YOLO("best.pt").export(
    format="tflite",
    imgsz=640,
    batch=1,
    half=True,
    int8=False,
    nms=False,
    device="cpu",
)
```

That reconstruction used macOS 26.6.2 arm64, Python 3.11.15, Ultralytics 8.4.7,
PyTorch 2.5.0, TensorFlow 2.19.0, ONNX 1.22.0, ONNX2TF 1.28.8, ONNX Slim 0.1.96,
and AI Edge LiteRT 1.3.0. It produced a 5,371,829-byte file with SHA-256
`2025ede440def713f8b91a7f02103bd688c87c589d6050dc92fed364925d365d`,
which is **not** byte-identical to the 5,372,822-byte app artifact. Whole-file
differences were not reduced to a cause, so only the frozen app checksum names
the benchmark candidate. Ultralytics documents `format` and the precision/NMS
options in its [official export guide](https://docs.ultralytics.com/modes/export/).

Facts verified directly from the app artifact are its Ultralytics `8.4.7`
metadata, embedded arguments and timestamp, tensor contract, local path, size,
and checksum. The original conversion OS, Python/PyTorch/TensorFlow versions,
command line, and source-checkpoint mapping remain unavailable; the versions
above belong only to the later reconstruction.

## Ownership, versions, and terms

| Layer | Ownership/publisher record | Frozen version | Terms evidence and unresolved rights |
| --- | --- | --- | --- |
| Source images and annotations | Public project attributed by Roboflow to `Automobile Damage Detection`; individual image creators/rightsholders and annotators are not enumerated in retained evidence. | Exact training export unknown; public `/1`, `/3`, and `/4` are possible context, not established lineage. | Roboflow displays `CC BY 4.0` for the public project. That statement does not identify every underlying image rightsholder, prove permission for every image, or establish that the trained split was the public export. A per-item permission/source ledger is unavailable and remains required. |
| Model weights | Published by Hugging Face user `vineetsarpal`; derived from an unpinned `yolo11n.pt` base and unidentified exact data export. | `best.pt` at `9f49ada03638abfa61ef21c2148ab1600c263e2b`, SHA-256 `cf3e55e63fd4564f68f78782be4e2608d26054753ba90762ab101dd22cdec962`; repository/card frozen at `ad93b6cbb6f1e14a385945c43cd36cf700385c86`. Android TFLite is separately identified above. | The owner card declares Apache-2.0. The Android TFLite metadata declares `AGPL-3.0 License (https://ultralytics.com/license)`. These are conflicting artifact-level statements; neither supersedes the other or resolves upstream base-model, training-data, image, annotation, trademark, privacy, or publicity rights. Distribution/commercial use requires an explicit rights review rather than choosing the more permissive label. |
| Mobile runtime | Ultralytics publishes `ultralytics_yolo`; Google publishes LiteRT. | Flutter package `0.6.14` (locked package SHA-256 `3848bc0cb1fa8726e59f15c402a3044f55b20b864fb7965c48910ffd79d2dea3`); its Android build declares `com.google.ai.edge.litert:litert:2.1.5` and `litert-metadata:1.4.2`. | Pub.dev identifies [`ultralytics_yolo`](https://pub.dev/packages/ultralytics_yolo/versions/0.6.14) as AGPL-3.0. Google's [LiteRT repository](https://github.com/google-ai-edge/LiteRT) declares Apache-2.0. Runtime terms are separate from weight and data terms and do not cure their lineage gaps. |

## Revalidation

Run from the repository root without building an APK:

```bash
shasum -a 256 android/app/src/main/assets/best.tflite
unzip -p android/app/src/main/assets/best.tflite metadata.json
git check-ignore -v android/app/src/main/assets/best.tflite
```

Expected SHA-256:
`56d8341be346bbc9ebe94a038405b5f5f3ef7fd172ffb3fb99e2ac0e38cb8734`.
Re-run FlatBuffer inspection whenever the checksum changes and verify the input,
output, dtype, shape, and class-ID assertions before updating this manifest.
