#!/usr/bin/env python3
"""Validate ATD-25 repository scaffolding and future evidence packages."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
from collections import defaultdict
from datetime import datetime
from pathlib import Path


CONTRACT_RELATIVE_PATH = Path("docs/research/severity_evaluation/contract.json")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def _read_csv(path: Path):
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or []), list(reader)


def _timestamp(value, field, errors):
    if value is None:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (AttributeError, ValueError):
        errors.append(f"{field} must be an ISO-8601 timestamp")
        return None


def validate_repository_contract(repository_root: Path):
    errors: list[str] = []
    contract_path = repository_root / CONTRACT_RELATIVE_PATH
    if not contract_path.is_file():
        return [f"missing repository contract: {contract_path}"]
    try:
        contract = json.loads(contract_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as error:
        return [f"invalid contract.json: {error}"]

    contract_directory = contract_path.parent
    schema_path = contract_directory / contract.get("manifest_schema", "")
    if not schema_path.is_file():
        errors.append(f"missing manifest schema: {schema_path}")
    else:
        try:
            schema = json.loads(schema_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as error:
            errors.append(f"invalid manifest schema: {error}")
            schema = {}
        if schema.get("$schema") != "https://json-schema.org/draft/2020-12/schema":
            errors.append("manifest schema must use JSON Schema draft 2020-12")

    if contract.get("schema_version") != 1 or contract.get("contract_version") != 1:
        errors.append("contract schema_version and contract_version must equal 1")
    if contract.get("hash_algorithm") != "sha256":
        errors.append("contract hash_algorithm must be sha256")

    public_rows: dict[str, list[dict[str, str]]] = {}
    for role, filename in contract.get("public_files", {}).items():
        path = contract_directory / filename
        if not path.is_file():
            errors.append(f"missing public matrix for {role}: {path}")
            continue
        columns, rows = _read_csv(path)
        if columns != contract.get("public_columns", {}).get(role):
            errors.append(f"{filename} columns do not match contract order")
        if not rows:
            errors.append(f"{filename} must contain explicit evidence-state rows")
        public_rows[role] = rows

    allowed_states = set(contract.get("evidence_states", []))
    for role, rows in public_rows.items():
        if "evidence_state" not in contract.get("public_columns", {}).get(role, []):
            continue
        for index, row in enumerate(rows, start=2):
            if row.get("evidence_state") not in allowed_states:
                errors.append(
                    f"{contract['public_files'][role]} row {index} has invalid evidence_state"
                )

    evidence_rows = public_rows.get("evidence_status", [])
    gate_ids = {row.get("evidence_id") for row in evidence_rows}
    expected_gate_ids = {value.replace("_", "-") for value in contract.get("completion_gates", [])}
    if not expected_gate_ids.issubset(gate_ids):
        errors.append("evidence_status.csv must name every completion gate")
    real_gate_rows = [row for row in evidence_rows if row.get("synthetic_only") == "false"]
    if any(row.get("availability") == "available" for row in real_gate_rows):
        errors.append("repository state must not claim real completion evidence is available")

    source_rows = public_rows.get("source_permissions", [])
    if any(row.get("corpus_eligibility") != "excluded" for row in source_rows):
        errors.append("unresolved public source rows must remain excluded")

    rubric_rows = public_rows.get("rubric_coverage", [])
    expected_pairs = {
        (str(class_id), severity)
        for class_id in range(14)
        for severity in ("Minor", "Moderate", "Severe")
    }
    actual_pairs = {(row.get("class_id"), row.get("severity_level")) for row in rubric_rows}
    if actual_pairs != expected_pairs:
        errors.append("rubric_coverage.csv must contain every class and pilot anchor")
    for row in rubric_rows:
        expected_anchor = contract.get("pilot_anchors", {}).get(row.get("severity_level"))
        if row.get("pilot_anchor") != expected_anchor:
            errors.append("rubric_coverage.csv has a severity-to-anchor mismatch")
        if row.get("qualified_appraiser_review") != "unavailable":
            errors.append("public rubric rows must preserve unavailable Appraiser review")

    if any(row.get("execution_state") != "not_run" for row in public_rows.get("model_experiments", [])):
        errors.append("public model experiments must remain not_run")
    if any(row.get("measurement_state") != "not_run" for row in public_rows.get("android_feasibility", [])):
        errors.append("public Android measurements must remain not_run")
    return errors


def _is_real(row):
    return row.get("synthetic") == "false" or row.get("synthetic_persona") == "false"


def _package_completion_errors(contract, manifest, tables):
    errors = []
    examples = tables.get("examples", [])
    rights = {row.get("rights_record_id"): row for row in tables.get("rights_records", [])}
    cleared_examples = [
        row
        for row in examples
        if _is_real(row)
        and (record := rights.get(row.get("rights_record_id")))
        and _is_real(record)
        and record.get("evidence_scope") == "item"
        and record.get("example_id") == row.get("example_id")
        and record.get("evaluation_permission") == "verified"
        and record.get("storage_permission") == "verified"
        and record.get("privacy_publicity_review") == "cleared"
        and not record.get("unresolved_constraints")
    ]
    if not cleared_examples:
        errors.append("unmet completion gate: rights_cleared_finding_examples")

    approved_rubrics = [
        row
        for row in tables.get("rubric_versions", [])
        if _is_real(row)
        and row.get("status") == "approved"
        and row.get("definition_target") == "component_relative_visible_damage_extent"
        and row.get("minor_anchor") == "localized"
        and row.get("moderate_anchor") == "intermediate"
        and row.get("severe_anchor") == "widespread"
        and row.get("approved_by")
        and row.get("approved_at")
    ]
    accepted_anchors = {
        row.get("severity_label")
        for row in tables.get("pilot_anchors", [])
        if _is_real(row)
        and row.get("review_status") == "accepted"
        and row.get("example_id")
        and row.get("reviewer_a_id")
        and row.get("reviewer_b_id")
        and row.get("adjudication_lead_id")
    }
    if not approved_rubrics or not {"Minor", "Moderate", "Severe"}.issubset(
        accepted_anchors
    ):
        errors.append("unmet completion gate: approved_rubric_and_boundaries")

    qualified_roles = {
        row.get("reviewer_role")
        for row in tables.get("reviewers", [])
        if _is_real(row)
        and row.get("qualification_status") == "verified"
        and row.get("qualification_evidence_uri")
        and SHA256_RE.fullmatch(row.get("qualification_evidence_sha256", ""))
    }
    if not {"qualified_appraiser_a", "qualified_appraiser_b"}.issubset(
        qualified_roles
    ):
        errors.append("unmet completion gate: two_independent_qualified_appraisers")
    if "adjudication_lead" not in qualified_roles:
        errors.append("unmet completion gate: designated_adjudication_lead")

    agreement_rows = [
        row
        for row in tables.get("agreement_results", [])
        if _is_real(row)
        and row.get("accepted_by")
        and row.get("accepted_at")
        and row.get("item_count", "").isdigit()
        and int(row["item_count"]) > 0
    ]
    real_adjudications = [
        row for row in tables.get("adjudications", []) if _is_real(row)
    ]
    if not agreement_rows or not real_adjudications:
        errors.append("unmet completion gate: agreement_and_adjudication_results")

    partition_rows = tables.get("partitions", [])
    present_partitions = {row.get("partition") for row in partition_rows}
    if (
        not set(contract.get("partitions", [])).issubset(present_partitions)
        or any(not row.get("sealed_at") for row in partition_rows)
    ):
        errors.append("unmet completion gate: leakage_resistant_partitions")

    models = [row for row in tables.get("model_identities", []) if _is_real(row)]
    evaluation_runs = [
        row
        for row in tables.get("evaluation_runs", [])
        if _is_real(row) and row.get("partition") == "final_test"
    ]
    roles = {row.get("candidate_role") for row in models}
    objectives = {row.get("objective") for row in models}
    if (
        "simple_baseline" not in roles
        or "compact_candidate" not in roles
        or not {"categorical", "ordinal"}.issubset(objectives)
        or not evaluation_runs
    ):
        errors.append("unmet completion gate: empirical_candidate_and_baseline_evaluation")
    if not tables.get("calibration_bins") or not tables.get("abstention_results"):
        errors.append("unmet completion gate: calibration_and_abstention_results")
    if not tables.get("detection_misses"):
        errors.append("unmet completion gate: end_to_end_detection_miss_results")

    parity_rows = [
        row
        for row in tables.get("export_parity", [])
        if _is_real(row)
        and row.get("status") == "accepted"
        and row.get("accepted_by")
        and row.get("accepted_at")
    ]
    if not parity_rows:
        errors.append("unmet completion gate: android_export_parity")

    android_rows = [
        row
        for row in tables.get("android_runs", [])
        if _is_real(row) and row.get("pipeline_scope") == "complete_pipeline"
    ]
    tiers = {row.get("device_tier") for row in android_rows}
    conditions = {row.get("run_condition") for row in android_rows}
    sustained_ids = {
        row.get("android_run_id") for row in tables.get("sustained_samples", [])
    }
    if (
        not {"low", "middle", "high"}.issubset(tiers)
        or not {"cold", "warm", "sustained"}.issubset(conditions)
        or not sustained_ids
    ):
        errors.append("unmet completion gate: representative_android_measurements")

    release_rows = [
        row
        for row in tables.get("release_reviews", [])
        if _is_real(row)
        and row.get("decision") == "accepted"
        and row.get("fallback_confirmed") == "true"
        and row.get("accepted_coverage")
        and row.get("accepted_thresholds")
        and row.get("accepted_limitations")
        and row.get("evidence_uri")
    ]
    release_roles = {row.get("reviewer_role") for row in release_rows}
    if "release_gate_owner" not in release_roles or not release_roles.intersection(
        {"qualified_appraiser_a", "qualified_appraiser_b", "adjudication_lead"}
    ):
        errors.append("unmet completion gate: human_release_gate_acceptance")
    if manifest.get("final_test_opened_at") is None:
        errors.append("completion requires a recorded final-test opening after selection freeze")
    return errors


def validate_evidence_package(package: Path, repository_root: Path, require_complete=False):
    errors: list[str] = []
    contract_path = repository_root / CONTRACT_RELATIVE_PATH
    contract = json.loads(contract_path.read_text(encoding="utf-8"))
    schema = json.loads(
        (contract_path.parent / contract["manifest_schema"]).read_text(encoding="utf-8")
    )
    manifest_path = package / "severity_evidence_manifest.json"
    if not manifest_path.is_file():
        return [f"missing severity evidence manifest: {manifest_path}"]
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as error:
        return [f"invalid severity evidence manifest: {error}"]

    required_fields = set(schema.get("required", []))
    missing_fields = sorted(required_fields - set(manifest))
    if missing_fields:
        errors.append(f"manifest missing fields: {', '.join(missing_fields)}")
    extra_fields = sorted(set(manifest) - set(schema.get("properties", {})))
    if extra_fields:
        errors.append(f"manifest has unsupported fields: {', '.join(extra_fields)}")
    if manifest.get("schema_version") != contract.get("schema_version"):
        errors.append("manifest schema_version does not match contract")
    if manifest.get("hash_algorithm") != "sha256":
        errors.append("manifest hash_algorithm must be sha256")
    if manifest.get("manifest_serialization") != "exact_utf8_bytes":
        errors.append("manifest must identify exact UTF-8 byte serialization")
    _timestamp(manifest.get("frozen_at"), "manifest.frozen_at", errors)
    selection_frozen_at = _timestamp(
        manifest.get("selection_frozen_at"),
        "manifest.selection_frozen_at",
        errors,
    )
    final_test_opened_at = _timestamp(
        manifest.get("final_test_opened_at"),
        "manifest.final_test_opened_at",
        errors,
    )
    if (
        selection_frozen_at is not None
        and final_test_opened_at is not None
        and final_test_opened_at < selection_frozen_at
    ):
        errors.append("final test was opened before selection freeze")

    records_by_role = {}
    tables: dict[str, list[dict[str, str]]] = {}
    for record in manifest.get("files", []):
        role = record.get("role", "")
        if role in records_by_role:
            errors.append(f"duplicate manifest role: {role}")
            continue
        records_by_role[role] = record
        expected_filename = contract.get("package_files", {}).get(role)
        if expected_filename is None:
            errors.append(f"unsupported manifest role: {role}")
            continue
        relative = Path(record.get("path", ""))
        if relative.is_absolute() or ".." in relative.parts:
            errors.append(f"manifest path for {role} must be a safe relative path")
            continue
        if record.get("path") != expected_filename:
            errors.append(f"manifest path for {role} must be {expected_filename}")
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
        elif hashlib.sha256(path.read_bytes()).hexdigest() != expected_hash:
            errors.append(f"checksum mismatch for {relative}")
        columns, rows = _read_csv(path)
        if columns != contract.get("package_columns", {}).get(role):
            errors.append(f"{relative} columns do not match {role} schema")
        tables[role] = rows

    expected_roles = set(contract.get("package_files", {}))
    if set(records_by_role) != expected_roles:
        errors.append(
            "manifest roles do not match contract: "
            f"expected {sorted(expected_roles)}, got {sorted(records_by_role)}"
        )

    partition_rows = tables.get("partitions", [])
    allowed_partitions = set(contract.get("partitions", []))
    for index, row in enumerate(partition_rows, start=2):
        if row.get("partition") not in allowed_partitions:
            errors.append(f"partitions.csv row {index} has invalid partition")
    for key in (
        "vehicle_group_id",
        "incident_group_id",
        "assessment_group_id",
        "session_group_id",
        "original_asset_id",
        "near_duplicate_group_id",
        "adjacent_frame_group_id",
        "allocation_group_id",
    ):
        partitions_by_value: dict[str, set[str]] = defaultdict(set)
        for row in partition_rows:
            if row.get(key):
                partitions_by_value[row[key]].add(row.get("partition", ""))
        for value, partitions in sorted(partitions_by_value.items()):
            if len(partitions) > 1:
                errors.append(
                    f"cross-partition leakage for {key}={value}: "
                    f"{', '.join(sorted(partitions))}"
                )
    rights_rows = tables.get("rights_records", [])
    rights_by_id = {}
    for index, row in enumerate(rights_rows, start=2):
        rights_id = row.get("rights_record_id", "")
        if not rights_id or rights_id in rights_by_id:
            errors.append(
                f"rights_records.csv row {index} has missing or duplicate rights_record_id"
            )
        rights_by_id[rights_id] = row
        if row.get("evidence_sha256") and not SHA256_RE.fullmatch(
            row.get("evidence_sha256", "")
        ):
            errors.append(f"rights_records.csv row {index} has invalid evidence SHA-256")

    for index, row in enumerate(tables.get("examples", []), start=2):
        rights = rights_by_id.get(row.get("rights_record_id", ""))
        rights_cleared = rights is not None and all(
            (
                rights.get("evidence_scope") == "item",
                rights.get("example_id") == row.get("example_id"),
                rights.get("source_id") == row.get("source_id"),
                rights.get("evaluation_permission") == "verified",
                rights.get("storage_permission") == "verified",
                rights.get("privacy_publicity_review") == "cleared",
                bool(rights.get("evidence_uri")),
                bool(SHA256_RE.fullmatch(rights.get("evidence_sha256", ""))),
                bool(rights.get("verified_by")),
                bool(rights.get("verified_at")),
                not rights.get("unresolved_constraints"),
            )
        )
        if not rights_cleared:
            errors.append(
                f"examples.csv row {index} lacks verified item-level rights for evaluation and storage"
            )
        if not SHA256_RE.fullmatch(row.get("content_sha256", "")):
            errors.append(f"examples.csv row {index} has invalid content SHA-256")
    reviewer_rows = tables.get("reviewers", [])
    reviewers_by_id = {}
    allowed_reviewer_roles = set(contract.get("required_reviewer_roles", []))
    for index, row in enumerate(reviewer_rows, start=2):
        reviewer_id = row.get("reviewer_id", "")
        if not reviewer_id or reviewer_id in reviewers_by_id:
            errors.append(f"reviewers.csv row {index} has missing or duplicate reviewer_id")
        reviewers_by_id[reviewer_id] = row
        if row.get("reviewer_role") not in allowed_reviewer_roles:
            errors.append(f"reviewers.csv row {index} has invalid reviewer_role")
        if row.get("synthetic_persona") not in {"true", "false"}:
            errors.append(f"reviewers.csv row {index} has invalid synthetic_persona")

    annotation_rows = tables.get("annotations", [])
    annotations_by_id = {}
    allowed_labels = set(contract.get("severity_labels", []))
    for index, row in enumerate(annotation_rows, start=2):
        annotation_id = row.get("annotation_id", "")
        if not annotation_id or annotation_id in annotations_by_id:
            errors.append(f"annotations.csv row {index} has missing or duplicate annotation_id")
        annotations_by_id[annotation_id] = row
        if row.get("severity_label") not in allowed_labels:
            errors.append(f"annotations.csv row {index} has invalid severity_label")
        if row.get("synthetic") not in {"true", "false"}:
            errors.append(f"annotations.csv row {index} has invalid synthetic flag")
        if row.get("independent_and_blinded") not in {"true", "false"}:
            errors.append(
                f"annotations.csv row {index} has invalid independent_and_blinded flag"
            )
        if row.get("reviewer_id") not in reviewers_by_id:
            errors.append(f"annotations.csv row {index} references unknown reviewer_id")

    ordinal_rank = {"Minor": 0, "Moderate": 1, "Severe": 2}
    disagreement_rows = tables.get("disagreements", [])
    disagreements_by_id = {}
    for index, row in enumerate(disagreement_rows, start=2):
        disagreement_id = row.get("disagreement_id", "")
        disagreements_by_id[disagreement_id] = row
        annotation_a = annotations_by_id.get(row.get("annotation_a_id", ""))
        annotation_b = annotations_by_id.get(row.get("annotation_b_id", ""))
        if annotation_a is None or annotation_b is None:
            errors.append(f"disagreements.csv row {index} references unknown annotations")
            continue
        if row.get("label_a") != annotation_a.get("severity_label") or row.get(
            "label_b"
        ) != annotation_b.get("severity_label"):
            errors.append(f"disagreements.csv row {index} does not preserve original labels")
        label_a = row.get("label_a")
        label_b = row.get("label_b")
        expected_distance = (
            abs(ordinal_rank[label_a] - ordinal_rank[label_b])
            if label_a in ordinal_rank and label_b in ordinal_rank
            else None
        )
        recorded_distance = row.get("ordinal_distance", "")
        if expected_distance is None:
            if recorded_distance:
                errors.append(
                    f"disagreements.csv row {index} ordinal_distance must be blank for Undetermined"
                )
        elif recorded_distance != str(expected_distance):
            errors.append(
                f"disagreements.csv row {index} ordinal_distance must equal {expected_distance}"
            )

    for index, row in enumerate(tables.get("adjudications", []), start=2):
        disagreement = disagreements_by_id.get(row.get("disagreement_id", ""))
        if disagreement is None:
            errors.append(f"adjudications.csv row {index} references unknown disagreement")
        reviewer = reviewers_by_id.get(row.get("lead_reviewer_id", ""))
        if reviewer is None or reviewer.get("reviewer_role") != "adjudication_lead":
            errors.append(
                f"adjudications.csv row {index} must use the designated adjudication lead"
            )
        if row.get("accepted_severity_label") not in allowed_labels:
            errors.append(f"adjudications.csv row {index} has invalid accepted severity label")
    if require_complete:
        errors.extend(_package_completion_errors(contract, manifest, tables))
        if any(row.get("synthetic_persona") == "true" for row in reviewer_rows):
            errors.append("synthetic reviewer cannot satisfy qualified Appraiser gates")
        if any(row.get("synthetic") == "true" for row in annotation_rows):
            errors.append("synthetic annotation cannot establish severity ground truth")
    return errors


def _completion_errors(contract: dict):
    return [f"unmet completion gate: {gate}" for gate in contract["completion_gates"]]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository-root", type=Path, default=Path.cwd())
    parser.add_argument("--package", type=Path)
    parser.add_argument("--require-complete", action="store_true")
    arguments = parser.parse_args()

    errors = validate_repository_contract(arguments.repository_root)
    contract_path = arguments.repository_root / CONTRACT_RELATIVE_PATH
    if arguments.require_complete and contract_path.is_file() and not arguments.package:
        contract = json.loads(contract_path.read_text(encoding="utf-8"))
        errors.extend(_completion_errors(contract))
    if arguments.package:
        errors.extend(
            validate_evidence_package(
                arguments.package,
                arguments.repository_root,
                require_complete=arguments.require_complete,
            )
        )

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1

    contract = json.loads(contract_path.read_text(encoding="utf-8"))
    print(
        "PASS: severity evidence repository contract; "
        f"{len(contract['completion_gates'])} unavailable completion gates recorded"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
