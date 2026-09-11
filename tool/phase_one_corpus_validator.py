#!/usr/bin/env python3
"""Validate the repository ATD-20 contract or an authorized corpus package."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
from collections import defaultdict
from datetime import datetime
from pathlib import Path


SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def _read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def _read_csv(path: Path):
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or []), list(reader)


def _sha256(path: Path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _timestamp(value: str | None, field: str, errors: list[str]):
    if value is None:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (AttributeError, ValueError):
        errors.append(f"{field} must be an ISO-8601 timestamp")
        return None


def _contract_path(repository_root: Path):
    return (
        repository_root
        / "docs/research/phase_one_evaluation_corpus/contract.json"
    )


def _repository_root_from_module():
    return Path(__file__).resolve().parents[1]


def validate_repository_contract(repository_root: Path):
    errors: list[str] = []
    contract_path = _contract_path(repository_root)
    mapping_path = contract_path.parent / "class_mapping.csv"
    ledger_path = contract_path.parent / "source_permission_ledger.csv"
    manifest_schema_path = contract_path.parent / "corpus_manifest.schema.json"
    provenance_path = repository_root / "docs/research/phase_one_model_provenance.md"

    for path in (
        contract_path,
        mapping_path,
        ledger_path,
        manifest_schema_path,
        provenance_path,
    ):
        if not path.is_file():
            errors.append(f"missing repository contract file: {path}")
    if errors:
        return errors

    try:
        contract = _read_json(contract_path)
    except (json.JSONDecodeError, OSError) as error:
        return [f"invalid contract.json: {error}"]

    if contract.get("schema_version") != 1 or contract.get("contract_version") != 1:
        errors.append("contract schema_version and contract_version must both equal 1")
    if contract.get("hash_algorithm") != "sha256":
        errors.append("contract hash_algorithm must be sha256")
    if contract.get("manifest_schema") != manifest_schema_path.name:
        errors.append("contract must reference corpus_manifest.schema.json")
    try:
        manifest_schema = _read_json(manifest_schema_path)
    except (json.JSONDecodeError, OSError) as error:
        errors.append(f"invalid corpus_manifest.schema.json: {error}")
        manifest_schema = {}
    if manifest_schema.get("$schema") != "https://json-schema.org/draft/2020-12/schema":
        errors.append("corpus manifest schema must use JSON Schema draft 2020-12")

    mapping_columns, mapping_rows = _read_csv(mapping_path)
    expected_mapping_columns = contract["table_columns"]["class_mapping"]
    if mapping_columns != expected_mapping_columns:
        errors.append("class_mapping.csv columns do not match contract order")
    expected_raw_classes = [
        "Front-windscreen-damage",
        "Headlight-damage",
        "Rear-windscreen-Damage",
        "Runningboard-Damage",
        "Sidemirror-Damage",
        "Taillight-Damage",
        "bonnet-dent",
        "boot-dent",
        "doorouter-dent",
        "fender-dent",
        "front-bumper-dent",
        "quaterpanel-dent",
        "rear-bumper-dent",
        "roof-dent",
    ]
    actual_ids = [row.get("class_id") for row in mapping_rows]
    actual_raw_classes = [row.get("raw_class") for row in mapping_rows]
    if actual_ids != [str(value) for value in range(14)]:
        errors.append("class_mapping.csv must contain class IDs 0 through 13 in order")
    if actual_raw_classes != expected_raw_classes:
        errors.append("class_mapping.csv raw classes do not match frozen TFLite metadata")
    if any(row.get("mapping_version") != "1" for row in mapping_rows):
        errors.append("every class mapping row must use mapping_version 1")
    for row in mapping_rows:
        rule = row.get("position_rule", "").lower()
        if row.get("required_observed_position") != "none" and not (
            "infer" in rule or "not identify" in rule or "not left or right" in rule
        ):
            errors.append(
                f"class {row.get('raw_class')} must state its no-position-inference rule"
            )
    provenance = provenance_path.read_text(encoding="utf-8")
    for raw_class in expected_raw_classes:
        if f"`{raw_class}`" not in provenance:
            errors.append(f"ATD-19 provenance is missing raw class {raw_class}")

    ledger_columns, ledger_rows = _read_csv(ledger_path)
    if ledger_columns != contract["repository_source_ledger_columns"]:
        errors.append("source_permission_ledger.csv columns do not match contract order")
    if not ledger_rows:
        errors.append("source_permission_ledger.csv must retain candidate-source evidence")
    for row in ledger_rows:
        if row.get("evidence_scope") != "dataset":
            errors.append("repository source ledger must not imply per-image evidence")
        if row.get("item_id"):
            errors.append("repository source ledger dataset rows must have blank item_id")
        if row.get("corpus_eligibility") != "excluded":
            errors.append("unresolved repository source rows must remain excluded")
        if not row.get("unresolved_constraints"):
            errors.append(
                f"source {row.get('source_id')} must record unresolved constraints"
            )
    return errors


def _validate_columns(role, path, columns, expected, errors):
    if columns != expected:
        errors.append(
            f"{path.name} columns do not match {role} schema: expected {expected}, got {columns}"
        )


def _cross_split(rows, key, errors):
    splits_by_value: dict[str, set[str]] = defaultdict(set)
    for row in rows:
        value = row.get(key, "")
        if value:
            splits_by_value[value].add(row.get("split", ""))
    for value, splits in sorted(splits_by_value.items()):
        if len(splits) > 1:
            errors.append(
                f"cross-split leakage for {key}={value}: {', '.join(sorted(splits))}"
            )


def _validate_counts(count_rows, images, annotations, errors):
    for index, row in enumerate(count_rows, start=2):
        try:
            declared = int(row.get("count", ""))
        except ValueError:
            errors.append(f"counts.csv row {index} count must be an integer")
            continue
        stratum_type = row.get("stratum_type")
        value = row.get("stratum_value")
        split = row.get("split")
        outcome = row.get("annotation_outcome")
        unit = row.get("count_unit")
        if unit == "images":
            records = images
            if stratum_type == "split":
                actual = sum(1 for item in records if item.get("split") == value)
            elif stratum_type in {
                "vehicle_damage_status",
                "supported_vehicle_type",
            }:
                actual = sum(
                    1
                    for item in records
                    if item.get(stratum_type) == value
                    and (not split or item.get("split") == split)
                )
            elif stratum_type == "condition":
                actual = sum(
                    1
                    for item in records
                    if value in set(filter(None, item.get("conditions", "").split(";")))
                    and (not split or item.get("split") == split)
                )
            else:
                errors.append(f"counts.csv row {index} has unsupported image stratum")
                continue
        elif unit == "annotations":
            records = annotations
            if stratum_type not in {
                "raw_class",
                "canonical_damage_type",
                "component_family",
                "component_position",
                "annotation_outcome",
            }:
                errors.append(f"counts.csv row {index} has unsupported annotation stratum")
                continue
            image_split = {item.get("item_id"): item.get("split") for item in images}
            actual = sum(
                1
                for annotation in records
                if annotation.get(stratum_type) == value
                and (outcome in {"", "all"} or annotation.get("annotation_outcome") == outcome)
                and (not split or image_split.get(annotation.get("item_id")) == split)
            )
        else:
            errors.append(f"counts.csv row {index} has unsupported count_unit {unit}")
            continue
        if actual != declared:
            errors.append(
                f"count mismatch at counts.csv row {index}: declared {declared}, computed {actual}"
            )


def validate_corpus_package(package: Path, require_complete: bool = False):
    errors: list[str] = []
    repository_root = _repository_root_from_module()
    contract = _read_json(_contract_path(repository_root))
    manifest_schema = _read_json(
        _contract_path(repository_root).parent / contract["manifest_schema"]
    )
    manifest_path = package / contract["required_files"]["manifest"]
    if not manifest_path.is_file():
        return [f"missing corpus manifest: {manifest_path}"]
    try:
        manifest = _read_json(manifest_path)
    except (json.JSONDecodeError, OSError) as error:
        return [f"invalid corpus_manifest.json: {error}"]

    required_manifest_fields = set(manifest_schema["required"])
    missing = sorted(required_manifest_fields - set(manifest))
    if missing:
        errors.append(f"corpus_manifest.json missing fields: {', '.join(missing)}")
    extra = sorted(set(manifest) - set(manifest_schema["properties"]))
    if extra:
        errors.append(f"corpus_manifest.json has unsupported fields: {', '.join(extra)}")
    if manifest.get("schema_version") != contract["schema_version"]:
        errors.append("corpus manifest schema_version does not match contract")
    if manifest.get("hash_algorithm") != "sha256":
        errors.append("corpus manifest hash_algorithm must be sha256")
    if manifest.get("manifest_serialization") != "exact_utf8_bytes":
        errors.append("corpus manifest must hash exact UTF-8 bytes")
    for field in ("model_artifact_sha256", "calibration_record_sha256"):
        if not SHA256_RE.fullmatch(manifest.get(field, "")):
            errors.append(f"corpus manifest {field} must be SHA-256")
    if manifest.get("final_test_use") != "confirmation_only":
        errors.append("final test use must be confirmation_only")
    if manifest.get("final_test_tuning_prohibited") is not True:
        errors.append("final-test tuning must be explicitly prohibited")
    if manifest.get("historical_training_manifest_reconciliation") != "unavailable_per_ATD-19":
        errors.append("historical training manifest reconciliation must preserve ATD-19 limit")

    files_by_role = {}
    for record in manifest.get("files", []):
        role = record.get("role", "")
        relative = Path(record.get("path", ""))
        if role in files_by_role:
            errors.append(f"duplicate manifest role: {role}")
            continue
        files_by_role[role] = record
        expected_filename = contract["required_files"].get(role)
        if expected_filename and record.get("path") != expected_filename:
            errors.append(
                f"manifest path for {role} must be {expected_filename}, got {record.get('path')}"
            )
        if relative.is_absolute() or ".." in relative.parts:
            errors.append(f"manifest path for {role} must be a safe relative path")
            continue
        path = package / relative
        if not path.is_file():
            errors.append(f"manifest file missing for {role}: {relative}")
            continue
        if record.get("bytes") != path.stat().st_size:
            errors.append(f"byte-length mismatch for {relative}")
        expected_hash = record.get("sha256", "")
        if not SHA256_RE.fullmatch(expected_hash):
            errors.append(f"invalid SHA-256 for {relative}")
        elif _sha256(path) != expected_hash:
            errors.append(f"checksum mismatch for {relative}")

    expected_roles = set(contract["required_files"]) - {"manifest"}
    if set(files_by_role) != expected_roles:
        errors.append(
            "manifest roles do not match contract: "
            f"expected {sorted(expected_roles)}, got {sorted(files_by_role)}"
        )

    tables = {}
    for role in sorted(expected_roles):
        filename = contract["required_files"][role]
        path = package / filename
        if not path.is_file():
            continue
        columns, rows = _read_csv(path)
        _validate_columns(role, path, columns, contract["table_columns"][role], errors)
        tables[role] = rows
    if expected_roles - set(tables):
        return errors

    expected_mapping = _read_csv(
        repository_root
        / "docs/research/phase_one_evaluation_corpus/class_mapping.csv"
    )[1]
    if tables["class_mapping"] != expected_mapping:
        errors.append("class_mapping.csv does not equal the frozen repository mapping")
    mapping_versions = {row.get("mapping_version") for row in tables["class_mapping"]}
    if mapping_versions != {manifest.get("class_mapping_version")}:
        errors.append("class_mapping_version does not match class_mapping.csv")

    images = tables["images"]
    annotations = tables["annotations"]
    permissions = tables["source_permissions"]
    counts = tables["counts"]
    valid_splits = set(contract["splits"])
    item_ids = [row.get("item_id", "") for row in images]
    if "" in item_ids or len(item_ids) != len(set(item_ids)):
        errors.append("images.csv item_id values must be non-empty and unique")
    for index, row in enumerate(images, start=2):
        if row.get("split") not in valid_splits:
            errors.append(f"images.csv row {index} has invalid split")
        for field in ("original_sha256", "canonical_sha256"):
            if not SHA256_RE.fullmatch(row.get(field, "")):
                errors.append(f"images.csv row {index} has invalid {field}")
        try:
            if int(row.get("bytes", "")) < 1:
                raise ValueError
        except ValueError:
            errors.append(f"images.csv row {index} bytes must be a positive integer")
    for key in (
        "vehicle_id",
        "assessment_id",
        "session_id",
        "original_asset_id",
        "original_sha256",
        "canonical_sha256",
        "near_duplicate_group_id",
        "adjacent_frame_group_id",
    ):
        _cross_split(images, key, errors)

    dataset_sources = {
        row.get("source_id")
        for row in permissions
        if row.get("evidence_scope") == "dataset"
        and row.get("claim_status") == "verified"
        and row.get("evidence_uri")
        and row.get("verified_by")
        and row.get("verified_at")
        and not row.get("unresolved_constraints")
    }
    permission_ids = [row.get("permission_record_id", "") for row in permissions]
    if "" in permission_ids or len(permission_ids) != len(set(permission_ids)):
        errors.append(
            "source_permissions.csv permission_record_id values must be non-empty and unique"
        )
    verified_item_permissions = {
        (row.get("source_id"), row.get("item_id"))
        for row in permissions
        if row.get("evidence_scope") == "item"
        and row.get("claim_type") == "storage_and_evaluation"
        and row.get("claim_status") == "verified"
        and row.get("evidence_uri")
        and SHA256_RE.fullmatch(row.get("evidence_sha256", ""))
        and row.get("verified_by")
        and row.get("verified_at")
        and not row.get("unresolved_constraints")
    }
    for image in images:
        source_id = image.get("source_id")
        item_id = image.get("item_id")
        if source_id not in dataset_sources:
            errors.append(f"item {item_id} has no verified dataset-level source record")
        if (source_id, item_id) not in verified_item_permissions:
            errors.append(f"item {item_id} has no verified item-level per-image rights record")

    annotation_ids = [row.get("annotation_id", "") for row in annotations]
    if "" in annotation_ids or len(annotation_ids) != len(set(annotation_ids)):
        errors.append("annotations.csv annotation_id values must be non-empty and unique")
    raw_classes = {row["raw_class"] for row in expected_mapping}
    for index, row in enumerate(annotations, start=2):
        if row.get("item_id") not in set(item_ids):
            errors.append(f"annotations.csv row {index} references an unknown item_id")
        outcome = row.get("annotation_outcome")
        if outcome not in contract["annotation_outcomes"]:
            errors.append(f"annotations.csv row {index} has invalid annotation_outcome")
        if row.get("visibility") not in contract["visibility_values"]:
            errors.append(f"annotations.csv row {index} has invalid visibility")
        if row.get("inspection_scope") not in contract["inspection_scope_values"]:
            errors.append(f"annotations.csv row {index} has invalid inspection_scope")
        if outcome == "negative" and (
            row.get("visibility") != "fully_visible"
            or row.get("inspection_scope") != "inspected"
        ):
            errors.append(
                f"annotations.csv row {index}: hidden or uninspected surfaces must not be recorded as negative"
            )
        if row.get("component_position_source") not in contract["component_position_sources"]:
            errors.append(
                f"annotations.csv row {index}: position must not be inferred from a raw class"
            )
        raw_class = row.get("raw_class")
        if raw_class and raw_class not in raw_classes:
            errors.append(f"annotations.csv row {index} has unknown raw_class")
        if outcome == "positive" and not row.get("physical_defect_id"):
            errors.append(f"annotations.csv row {index} positive requires physical_defect_id")
        if outcome == "out_of_scope" and not row.get("unsupported_damage_type"):
            errors.append(f"annotations.csv row {index} out_of_scope requires a description")

    defect_identity = {}
    for row in annotations:
        defect_id = row.get("physical_defect_id")
        if not defect_id:
            continue
        identity = (
            row.get("canonical_damage_type"),
            row.get("component_family"),
            row.get("component_position"),
        )
        previous = defect_identity.setdefault(defect_id, identity)
        if previous != identity:
            errors.append(
                f"physical_defect_id {defect_id} has inconsistent damage/component identity across views"
            )

    adjudicated_annotations = set()
    for index, row in enumerate(tables["adjudications"], start=2):
        if row.get("annotation_id") not in set(annotation_ids):
            errors.append(f"adjudications.csv row {index} references an unknown annotation")
        if row.get("reviewer_role") != "Appraiser":
            errors.append(f"adjudications.csv row {index} reviewer_role must be Appraiser")
        if not row.get("reviewer_pseudonymous_id") or not row.get("decided_at"):
            errors.append(f"adjudications.csv row {index} lacks reviewer or decision time")
        if row.get("guideline_version") != manifest.get("annotation_guideline_version"):
            errors.append(
                f"adjudications.csv row {index} guideline_version does not match manifest"
            )
        adjudicated_annotations.add(row.get("annotation_id"))

    _validate_counts(counts, images, annotations, errors)

    audit_ids = []
    allowed_audit_findings = {
        "no_cross_split_leakage",
        "candidate_overlap",
        "confirmed_leakage",
        "resolved_before_split",
    }
    for index, row in enumerate(tables["leakage_audit"], start=2):
        audit_ids.append(row.get("audit_record_id", ""))
        if row.get("finding") not in allowed_audit_findings:
            errors.append(f"leakage_audit.csv row {index} has invalid finding")
        for field in ("left_item_id", "right_item_id"):
            if row.get(field) and row.get(field) not in set(item_ids):
                errors.append(
                    f"leakage_audit.csv row {index} {field} references an unknown item"
                )
    if "" in audit_ids or len(audit_ids) != len(set(audit_ids)):
        errors.append(
            "leakage_audit.csv audit_record_id values must be non-empty and unique"
        )

    selection_frozen = _timestamp(
        manifest.get("selection_frozen_at"), "selection_frozen_at", errors
    )
    final_opened = _timestamp(
        manifest.get("final_test_opened_at"), "final_test_opened_at", errors
    )
    _timestamp(manifest.get("frozen_at"), "frozen_at", errors)
    if final_opened and selection_frozen and final_opened < selection_frozen:
        errors.append("final test was opened before model and selection freeze")

    if require_complete:
        digest_path = package / "corpus_manifest.sha256"
        if not digest_path.is_file():
            errors.append("completion requires corpus_manifest.sha256")
        else:
            declared = digest_path.read_text(encoding="utf-8").strip().split()[0]
            if declared != _sha256(manifest_path):
                errors.append("corpus_manifest.sha256 does not match corpus_manifest.json")
        if not manifest.get("access_controlled_location"):
            errors.append("completion requires an access-controlled corpus location")
        if {
            (row.get("source_id"), row.get("item_id")) for row in images
        } - verified_item_permissions:
            errors.append("completion requires verified item-level permissions for every image")
        if not annotations or set(annotation_ids) - adjudicated_annotations:
            errors.append("completion requires real Appraiser adjudication for every annotation")
        if final_opened is None:
            errors.append("completion requires a recorded final-test opening after selection freeze")
        required_count_strata = {
            "raw_class",
            "canonical_damage_type",
            "component_family",
            "component_position",
            "annotation_outcome",
            "condition",
            "supported_vehicle_type",
            "vehicle_damage_status",
            "split",
        }
        present_strata = set()
        for row in counts:
            try:
                if int(row.get("count", "0")) > 0:
                    present_strata.add(row.get("stratum_type"))
            except ValueError:
                continue
        missing_strata = sorted(required_count_strata - present_strata)
        if missing_strata:
            errors.append(
                "completion requires populated count strata: " + ", ".join(missing_strata)
            )
        positive_annotations = [
            row for row in annotations if row.get("annotation_outcome") == "positive"
        ]
        covered_raw_classes = {row.get("raw_class") for row in positive_annotations}
        missing_raw_classes = sorted(raw_classes - covered_raw_classes)
        if missing_raw_classes:
            errors.append(
                "completion requires positive coverage for raw classes: "
                + ", ".join(missing_raw_classes)
            )
        covered_conditions = {
            condition
            for row in images
            for condition in filter(None, row.get("conditions", "").split(";"))
        }
        missing_conditions = sorted(
            set(contract["required_conditions"]) - covered_conditions
        )
        if missing_conditions:
            errors.append(
                "completion requires capture conditions: " + ", ".join(missing_conditions)
            )
        covered_statuses = {row.get("vehicle_damage_status") for row in images}
        if set(contract["required_vehicle_damage_statuses"]) - covered_statuses:
            errors.append("completion requires damaged and undamaged Vehicles")
        covered_vehicle_types = {row.get("supported_vehicle_type") for row in images}
        if set(contract["supported_vehicle_types"]) - covered_vehicle_types:
            errors.append("completion requires every supported vehicle type")
        image_by_id = {row.get("item_id"): row for row in images}
        if not any(
            row.get("annotation_outcome") == "negative"
            and image_by_id.get(row.get("item_id"), {}).get("vehicle_damage_status")
            == "damaged"
            for row in annotations
        ):
            errors.append("completion requires undamaged components on damaged Vehicles")
        if not any(
            row.get("annotation_outcome") == "out_of_scope" for row in annotations
        ):
            errors.append("completion requires visible out-of-scope damage coverage")
        required_count_rows = {
            ("raw_class", raw_class, split)
            for raw_class in raw_classes
            for split in contract["splits"]
        } | {
            ("condition", condition, split)
            for condition in contract["required_conditions"]
            for split in contract["splits"]
        }
        actual_count_rows = {
            (row.get("stratum_type"), row.get("stratum_value"), row.get("split"))
            for row in counts
        }
        missing_count_rows = required_count_rows - actual_count_rows
        if missing_count_rows:
            errors.append(
                "completion requires per-class/per-condition counts for every split"
            )
        audit_rows = tables["leakage_audit"]
        if not audit_rows or any(
            row.get("finding") != "no_cross_split_leakage"
            or not row.get("audited_by")
            or not row.get("audited_at")
            or not row.get("tool_version")
            for row in audit_rows
        ):
            errors.append("completion requires a completed zero-unresolved leakage audit")
    return errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path)
    parser.add_argument("--package", type=Path)
    parser.add_argument("--require-complete", action="store_true")
    arguments = parser.parse_args()
    if bool(arguments.repository_root) == bool(arguments.package):
        parser.error("provide exactly one of --repository-root or --package")
    if arguments.repository_root:
        errors = validate_repository_contract(arguments.repository_root.resolve())
    else:
        errors = validate_corpus_package(
            arguments.package.resolve(), require_complete=arguments.require_complete
        )
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        raise SystemExit(1)
    print("PASS")


if __name__ == "__main__":
    main()
