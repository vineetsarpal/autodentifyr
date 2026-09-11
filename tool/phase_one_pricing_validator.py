#!/usr/bin/env python3
"""Validate the repository-safe ATD-22 contract or an authorized evidence package."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sys
from collections import Counter, defaultdict
from datetime import date, datetime
from pathlib import Path


RAW_CLASSES = [
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

POSITION_REQUIREMENTS = {
    "Front-windscreen-damage": "none",
    "Headlight-damage": "lateral",
    "Rear-windscreen-Damage": "none",
    "Runningboard-Damage": "lateral",
    "Sidemirror-Damage": "lateral",
    "Taillight-Damage": "lateral",
    "bonnet-dent": "none",
    "boot-dent": "none",
    "doorouter-dent": "lateral_and_longitudinal",
    "fender-dent": "lateral_and_longitudinal",
    "front-bumper-dent": "none",
    "quaterpanel-dent": "lateral_and_longitudinal",
    "rear-bumper-dent": "none",
    "roof-dent": "none",
}

STATUS_VALUES = {"verified", "proposed", "unavailable", "permission-required", "excluded"}
PERMISSION_VALUES = {"verified", "permission-required", "unavailable", "excluded"}
COVERAGE_VALUES = {"supported", "unsupported", "unresolved"}
PRICING_VALUES = {"verified", "proposed", "unavailable", "excluded"}
EVIDENCE_TYPES = {"repair_shop_records", "commercial_estimating_extract", "proposed_assumption"}
ESTIMATE_INVOICE_VALUES = {"estimate", "completed_invoice", "proposed_assumption"}
SUPPLEMENT_VALUES = {"none", "pending", "partial", "final_includes_supplements", "unknown", "not_applicable"}
ID_PATTERN = re.compile(r"^[a-z][a-z0-9-]*$")
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")

SOURCE_COLUMNS = [
    "source_id", "source_owner", "source_name", "source_version",
    "collection_period_start", "collection_period_end", "geography", "currency",
    "evidence_type", "estimate_invoice_status", "supplement_status", "parts_basis",
    "labor_categories", "materials_basis", "inclusions", "exclusions", "refresh_date",
    "publisher_claim_status", "contractual_entitlement_status", "dataset_rights_status",
    "record_rights_status", "derived_ranges_permission", "application_display_permission",
    "device_local_storage_permission", "offline_use_permission", "updates_permission",
    "retained_revisions_permission", "internal_evaluation_permission",
    "publication_permission", "redistribution_permission", "permission_evidence_reference",
]

OPERATION_COLUMNS = [
    "pricing_record_id", "source_id", "source_version", "cohort_id",
    "repair_operation_id", "shared_operation_group_id", "component_id", "damage_type",
    "vehicle_context", "geography", "currency", "evidence_type",
    "estimate_invoice_status", "supplement_status", "minimum_amount_minor",
    "maximum_amount_minor", "pricing_status", "included_operation_ids", "exclusions",
    "observed_at",
]

COVERAGE_COLUMNS = [
    "coverage_id", "raw_class", "component_family", "required_component_position",
    "damage_type", "cohort_id", "repair_operation_id", "vehicle_context", "geography",
    "currency", "source_id", "coverage_status", "pricing_status",
    "missing_pricing_behavior", "unresolved_reason",
]

REVIEW_COLUMNS = [
    "review_id", "review_type", "record_id", "reviewer_role", "reviewer_id",
    "decision", "reviewed_at", "rationale",
]

PACKAGE_FILES = {
    "source_records": "source_records.csv",
    "operation_records": "operation_records.csv",
    "coverage_matrix": "coverage_matrix.csv",
    "review_records": "review_records.csv",
}


class Validation:
    def __init__(self) -> None:
        self.errors: list[str] = []

    def error(self, message: str) -> None:
        self.errors.append(message)

    def require(self, condition: bool, message: str) -> None:
        if not condition:
            self.error(message)


def read_csv(path: Path, expected_columns: list[str], validation: Validation) -> list[dict[str, str]]:
    if not path.is_file():
        validation.error(f"missing required file: {path.name}")
        return []
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        actual = reader.fieldnames or []
        validation.require(actual == expected_columns, f"{path.name}: required schema fields do not match")
        rows: list[dict[str, str]] = []
        for line_number, raw_row in enumerate(reader, start=2):
            if None in raw_row or any(value is None for value in raw_row.values()):
                validation.error(f"{path.name}:{line_number}: row width does not match schema")
            rows.append({str(key): value or "" for key, value in raw_row.items() if key is not None})
        return rows


def valid_date(value: str) -> bool:
    try:
        date.fromisoformat(value)
        return True
    except ValueError:
        return False


def valid_datetime(value: str) -> bool:
    try:
        datetime.fromisoformat(value.replace("Z", "+00:00"))
        return True
    except ValueError:
        return False


def validate_id(value: str, field: str, validation: Validation) -> None:
    validation.require(bool(ID_PATTERN.fullmatch(value)), f"{field}: invalid identifier {value!r}")


def load_json(path: Path, validation: Validation) -> dict[str, object]:
    if not path.is_file():
        validation.error(f"missing required file: {path.name}")
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        validation.error(f"{path.name}: invalid JSON: {error}")
        return {}
    if not isinstance(value, dict):
        validation.error(f"{path.name}: root must be an object")
        return {}
    return value


def extract_dart_price_map(text: str, declaration: str, validation: Validation) -> dict[str, str]:
    start = text.find(declaration)
    if start < 0:
        validation.error(f"application placeholder declaration not found: {declaration}")
        return {}
    end = text.find("};", start)
    if end < 0:
        validation.error(f"application placeholder map is unterminated: {declaration}")
        return {}
    return {
        key: value.removesuffix(".0")
        for key, value in re.findall(r"'([^']+)'\s*:\s*([0-9]+(?:\.[0-9]+)?)", text[start:end])
    }


def validate_manifest(package: Path, validation: Validation) -> dict[str, object]:
    manifest = load_json(package / "pricing_manifest.json", validation)
    required = {
        "schema_version", "package_version", "frozen_at", "hash_algorithm",
        "manifest_serialization", "access_controlled_location", "geography", "currency",
        "coverage_contract_version", "files",
    }
    validation.require(set(manifest) == required, "pricing_manifest.json: required schema fields do not match")
    validation.require(manifest.get("schema_version") == 1, "manifest schema_version must be 1")
    validation.require(manifest.get("hash_algorithm") == "sha256", "manifest hash_algorithm must be sha256")
    validation.require(manifest.get("manifest_serialization") == "exact_utf8_bytes", "manifest serialization must be exact_utf8_bytes")
    validation.require(manifest.get("geography") == "US", "manifest geography must be US")
    validation.require(manifest.get("currency") == "USD", "manifest currency must be USD")
    validation.require(bool(manifest.get("access_controlled_location")), "manifest access-controlled location is required")
    validation.require(isinstance(manifest.get("frozen_at"), str) and valid_datetime(str(manifest.get("frozen_at"))), "manifest frozen_at must be an ISO date-time")
    files = manifest.get("files")
    if not isinstance(files, list):
        validation.error("manifest files must be an array")
        return manifest
    roles = [record.get("role") for record in files if isinstance(record, dict)]
    validation.require(Counter(roles) == Counter(PACKAGE_FILES.keys()), "manifest must list each required file role exactly once")
    for record in files:
        if not isinstance(record, dict):
            validation.error("manifest file record must be an object")
            continue
        role = str(record.get("role", ""))
        path_value = str(record.get("path", ""))
        expected_name = PACKAGE_FILES.get(role)
        validation.require(path_value == expected_name, f"manifest role {role}: path must be {expected_name}")
        if not expected_name:
            continue
        path = package / expected_name
        if not path.is_file():
            validation.error(f"manifest file missing: {expected_name}")
            continue
        content = path.read_bytes()
        validation.require(record.get("bytes") == len(content), f"{expected_name}: byte length mismatch")
        digest = hashlib.sha256(content).hexdigest()
        validation.require(record.get("sha256") == digest, f"{expected_name}: sha256 mismatch")
    return manifest


def validate_sources(rows: list[dict[str, str]], validation: Validation) -> dict[str, dict[str, str]]:
    sources: dict[str, dict[str, str]] = {}
    permission_fields = [
        "contractual_entitlement_status", "dataset_rights_status", "record_rights_status",
        "derived_ranges_permission", "application_display_permission",
        "device_local_storage_permission", "offline_use_permission", "updates_permission",
        "retained_revisions_permission", "internal_evaluation_permission",
        "publication_permission", "redistribution_permission",
    ]
    for row in rows:
        source_id = row.get("source_id", "")
        validate_id(source_id, "source_id", validation)
        validation.require(source_id not in sources, f"duplicate source_id: {source_id}")
        sources[source_id] = row
        for field in SOURCE_COLUMNS:
            validation.require(bool(row.get(field, "").strip()), f"{source_id}: required source field {field} is blank")
        validation.require(row.get("publisher_claim_status") in STATUS_VALUES, f"{source_id}: invalid publisher claim status")
        for field in permission_fields:
            validation.require(row.get(field) in PERMISSION_VALUES, f"{source_id}: invalid permission status in {field}")
        validation.require(row.get("geography") == "US", f"{source_id}: geography must be US")
        validation.require(row.get("currency") == "USD", f"{source_id}: currency must be USD")
        validation.require(row.get("evidence_type") in EVIDENCE_TYPES, f"{source_id}: invalid evidence type")
        validation.require(row.get("estimate_invoice_status") in ESTIMATE_INVOICE_VALUES, f"{source_id}: invalid estimate/invoice status")
        validation.require(row.get("supplement_status") in SUPPLEMENT_VALUES, f"{source_id}: invalid supplement status")
        for field in ("collection_period_start", "collection_period_end", "refresh_date"):
            validation.require(valid_date(row.get(field, "")), f"{source_id}: invalid date in {field}")
        if all(valid_date(row.get(field, "")) for field in ("collection_period_start", "collection_period_end", "refresh_date")):
            start = date.fromisoformat(row["collection_period_start"])
            end = date.fromisoformat(row["collection_period_end"])
            refresh = date.fromisoformat(row["refresh_date"])
            validation.require(start <= end <= refresh, f"{source_id}: collection period and refresh date are inconsistent")
    return sources


def parse_amount(value: str, record_id: str, field: str, validation: Validation) -> int | None:
    if value == "":
        return None
    try:
        amount = int(value)
    except ValueError:
        validation.error(f"{record_id}: {field} must be an integer minor-unit amount")
        return None
    validation.require(amount >= 0, f"{record_id}: {field} must not be negative")
    return amount


def validate_operations(rows: list[dict[str, str]], sources: dict[str, dict[str, str]], validation: Validation) -> list[dict[str, str]]:
    ids: set[str] = set()
    cohort_keys: dict[tuple[str, ...], dict[str, str]] = {}
    shared_groups: defaultdict[str, list[str]] = defaultdict(list)
    for row in rows:
        record_id = row.get("pricing_record_id", "")
        validate_id(record_id, "pricing_record_id", validation)
        validation.require(record_id not in ids, f"duplicate pricing_record_id: {record_id}")
        ids.add(record_id)
        for field in ("source_id", "cohort_id", "repair_operation_id", "shared_operation_group_id"):
            validate_id(row.get(field, ""), field, validation)
        source = sources.get(row.get("source_id", ""))
        validation.require(source is not None, f"{record_id}: unknown source_id")
        if source:
            validation.require(row.get("source_version") == source.get("source_version"), f"{record_id}: source-version mismatch")
            for field in ("geography", "currency", "evidence_type", "estimate_invoice_status", "supplement_status"):
                validation.require(row.get(field) == source.get(field), f"{record_id}: {field} is inconsistent with source")
        validation.require(row.get("geography") == "US", f"{record_id}: geography must be US")
        validation.require(row.get("currency") == "USD", f"{record_id}: currency must be USD")
        validation.require(row.get("evidence_type") in EVIDENCE_TYPES, f"{record_id}: invalid evidence type")
        validation.require(row.get("estimate_invoice_status") in ESTIMATE_INVOICE_VALUES, f"{record_id}: invalid estimate/invoice status")
        validation.require(row.get("supplement_status") in SUPPLEMENT_VALUES, f"{record_id}: invalid supplement status")
        validation.require(row.get("pricing_status") in PRICING_VALUES, f"{record_id}: invalid pricing status")
        validation.require(valid_date(row.get("observed_at", "")), f"{record_id}: observed_at must be an ISO date")
        minimum = parse_amount(row.get("minimum_amount_minor", ""), record_id, "minimum_amount_minor", validation)
        maximum = parse_amount(row.get("maximum_amount_minor", ""), record_id, "maximum_amount_minor", validation)
        if row.get("pricing_status") == "unavailable":
            validation.require(minimum is None and maximum is None, f"{record_id}: unavailable pricing must not contain amounts")
        if row.get("pricing_status") == "verified":
            validation.require(minimum is not None and maximum is not None, f"{record_id}: verified pricing requires both amounts")
            if minimum is not None and maximum is not None:
                validation.require(minimum <= maximum, f"{record_id}: minimum exceeds maximum")
        if row.get("estimate_invoice_status") == "proposed_assumption":
            validation.require(row.get("pricing_status") != "verified", f"{record_id}: proposed assumptions cannot be verified pricing")
        key = tuple(row.get(field, "") for field in (
            "source_id", "source_version", "cohort_id", "repair_operation_id",
            "vehicle_context", "geography", "currency", "estimate_invoice_status", "supplement_status",
        ))
        if key in cohort_keys:
            validation.error(f"{record_id}: conflicting pricing records for one source-version cohort")
        else:
            cohort_keys[key] = row
        shared_groups[row.get("shared_operation_group_id", "")].append(record_id)
    for group_id, record_ids in shared_groups.items():
        if group_id and len(record_ids) > 1:
            validation.error(f"{group_id}: shared operation group counted more than once: {', '.join(record_ids)}")
    return rows


def validate_coverage(rows: list[dict[str, str]], operations: list[dict[str, str]], validation: Validation) -> None:
    operation_index: defaultdict[tuple[str, str, str], list[dict[str, str]]] = defaultdict(list)
    for row in operations:
        operation_index[(row.get("source_id", ""), row.get("cohort_id", ""), row.get("repair_operation_id", ""))].append(row)
    ids: set[str] = set()
    for row in rows:
        coverage_id = row.get("coverage_id", "")
        validate_id(coverage_id, "coverage_id", validation)
        validation.require(coverage_id not in ids, f"duplicate coverage_id: {coverage_id}")
        ids.add(coverage_id)
        validation.require(row.get("raw_class") in RAW_CLASSES, f"{coverage_id}: unknown raw class")
        expected_position = POSITION_REQUIREMENTS.get(row.get("raw_class", ""))
        validation.require(row.get("required_component_position") == expected_position, f"{coverage_id}: raw class must not imply unsupported component position")
        validation.require(row.get("coverage_status") in COVERAGE_VALUES, f"{coverage_id}: invalid coverage status")
        validation.require(row.get("pricing_status") in PRICING_VALUES, f"{coverage_id}: invalid pricing status")
        validation.require(row.get("missing_pricing_behavior") == "unavailable", f"{coverage_id}: missing pricing must remain unavailable")
        validation.require(row.get("geography") == "US" and row.get("currency") == "USD", f"{coverage_id}: coverage must be US/USD")
        key = (row.get("source_id", ""), row.get("cohort_id", ""), row.get("repair_operation_id", ""))
        matches = operation_index.get(key, [])
        if row.get("coverage_status") == "supported":
            validation.require(row.get("pricing_status") == "verified" and len(matches) == 1 and matches[0].get("pricing_status") == "verified", f"{coverage_id}: supported coverage requires verified pricing")
        else:
            validation.require(bool(row.get("unresolved_reason", "").strip()), f"{coverage_id}: unsupported or unresolved coverage requires a reason")
            validation.require(row.get("pricing_status") != "verified", f"{coverage_id}: unsupported cohorts must not claim verified pricing")


def validate_reviews(rows: list[dict[str, str]], validation: Validation) -> None:
    ids: set[str] = set()
    for row in rows:
        review_id = row.get("review_id", "")
        validate_id(review_id, "review_id", validation)
        validation.require(review_id not in ids, f"duplicate review_id: {review_id}")
        ids.add(review_id)
        validation.require(row.get("reviewer_role") in {"appraiser", "product_owner"}, f"{review_id}: invalid reviewer role")
        validation.require(row.get("decision") in {"accepted", "rejected", "needs_revision"}, f"{review_id}: invalid review decision")
        validation.require(valid_date(row.get("reviewed_at", "")), f"{review_id}: reviewed_at must be an ISO date")
        validation.require(bool(row.get("rationale", "").strip()), f"{review_id}: rationale is required")


def validate_package(package: Path, require_complete: bool) -> Validation:
    validation = Validation()
    validate_manifest(package, validation)
    sources = validate_sources(read_csv(package / PACKAGE_FILES["source_records"], SOURCE_COLUMNS, validation), validation)
    operations = validate_operations(read_csv(package / PACKAGE_FILES["operation_records"], OPERATION_COLUMNS, validation), sources, validation)
    coverage = read_csv(package / PACKAGE_FILES["coverage_matrix"], COVERAGE_COLUMNS, validation)
    validate_coverage(coverage, operations, validation)
    reviews = read_csv(package / PACKAGE_FILES["review_records"], REVIEW_COLUMNS, validation)
    validate_reviews(reviews, validation)
    if require_complete:
        critical_permissions = {
            "contractual_entitlement_status", "dataset_rights_status", "record_rights_status",
            "derived_ranges_permission", "application_display_permission",
            "device_local_storage_permission", "offline_use_permission", "updates_permission",
            "retained_revisions_permission", "internal_evaluation_permission",
        }
        validation.require(bool(sources) and all(all(row.get(field) == "verified" for field in critical_permissions) for row in sources.values()), "complete package requires verified rights and access")
        validation.require({row.get("raw_class") for row in coverage if row.get("coverage_status") == "supported"} == set(RAW_CLASSES), "complete package requires populated supported coverage for all 14 raw classes or an approved scope revision")
        accepted_roles = {row.get("reviewer_role") for row in reviews if row.get("decision") == "accepted"}
        validation.require({"appraiser", "product_owner"} <= accepted_roles, "complete package requires Appraiser and product-owner acceptance")
    return validation


def validate_repository(root: Path, require_complete: bool) -> Validation:
    validation = Validation()
    base = root / "docs" / "research" / "phase_one_pricing_evidence"
    contract = load_json(base / "contract.json", validation)
    validation.require(contract.get("schema_version") == 1, "contract schema_version must be 1")
    validation.require(contract.get("geography") == "US" and contract.get("currency") == "USD", "contract must be US/USD")
    validation.require(contract.get("required_raw_classes") == RAW_CLASSES, "contract must contain the exact ordered 14 raw classes")
    source_columns = [
        "schema_version", "ledger_version", "source_id", "source_name", "source_route",
        "source_version", "publisher_claim_status", "publisher_claim_evidence_uri",
        "contractual_entitlement_status", "contractual_evidence_reference",
        "dataset_rights_status", "record_rights_status", "derived_ranges_permission",
        "application_display_permission", "device_local_storage_permission",
        "offline_use_permission", "updates_permission", "retained_revisions_permission",
        "internal_evaluation_permission", "publication_permission", "redistribution_permission",
        "evidence_status", "coverage_eligibility", "unresolved_requirements",
    ]
    expected_package_columns = {
        "source_records": SOURCE_COLUMNS,
        "operation_records": OPERATION_COLUMNS,
        "coverage_matrix": COVERAGE_COLUMNS,
        "review_records": REVIEW_COLUMNS,
    }
    validation.require(
        contract.get("evidence_package_table_columns") == expected_package_columns,
        "contract evidence-package table schemas do not match the validator",
    )
    source_rows = read_csv(base / "source_permission_ledger.csv", source_columns, validation)
    for row in source_rows:
        validate_id(row.get("source_id", ""), "source_id", validation)
        validation.require(row.get("publisher_claim_status") in STATUS_VALUES, f"{row.get('source_id')}: invalid publisher status")
        for field in (
            "contractual_entitlement_status", "dataset_rights_status", "record_rights_status",
            "derived_ranges_permission", "application_display_permission",
            "device_local_storage_permission", "offline_use_permission", "updates_permission",
            "retained_revisions_permission", "internal_evaluation_permission",
            "publication_permission", "redistribution_permission",
        ):
            validation.require(row.get(field) in PERMISSION_VALUES, f"{row.get('source_id')}: invalid {field}")
        validation.require(row.get("evidence_status") in STATUS_VALUES, f"{row.get('source_id')}: invalid evidence status")
        validation.require(row.get("coverage_eligibility") == "excluded", f"{row.get('source_id')}: unauthorized source must remain excluded")
        validation.require(bool(row.get("unresolved_requirements", "").strip()), f"{row.get('source_id')}: unresolved requirements are required")

    coverage_columns = [
        "schema_version", "mapping_version", "coverage_id", "class_id", "raw_class",
        "component_family", "raw_longitudinal_position", "required_component_position",
        "position_rule", "damage_type", "cohort_id", "repair_operation_options",
        "vehicle_context", "geography", "currency", "source_id", "coverage_status",
        "pricing_status", "missing_pricing_behavior", "unresolved_requirements",
    ]
    coverage_rows = read_csv(base / "class_operation_coverage.csv", coverage_columns, validation)
    validation.require(len(coverage_rows) == 14, "class_operation_coverage.csv must contain 14 raw classes")
    ordered_classes = [row.get("raw_class") for row in sorted(coverage_rows, key=lambda row: int(row.get("class_id", "-1")))] if coverage_rows else []
    validation.require(ordered_classes == RAW_CLASSES, "class operation mapping must match the exact ordered 14 raw classes")
    corpus_mapping_path = root / "docs" / "research" / "phase_one_evaluation_corpus" / "class_mapping.csv"
    if corpus_mapping_path.is_file():
        with corpus_mapping_path.open(newline="", encoding="utf-8") as handle:
            corpus_rows = list(csv.DictReader(handle))
        corpus_by_class = {row.get("raw_class", ""): row for row in corpus_rows}
        validation.require([row.get("raw_class") for row in sorted(corpus_rows, key=lambda row: int(row.get("class_id", "-1")))] == RAW_CLASSES, "ATD-20 mapping must contain the exact ordered 14 raw classes")
        for row in coverage_rows:
            corpus_row = corpus_by_class.get(row.get("raw_class", ""), {})
            for pricing_field, corpus_field in (
                ("component_family", "component_family"),
                ("raw_longitudinal_position", "raw_longitudinal_position"),
                ("required_component_position", "required_observed_position"),
                ("damage_type", "canonical_damage_type"),
            ):
                validation.require(row.get(pricing_field) == corpus_row.get(corpus_field), f"{row.get('raw_class')}: pricing mapping conflicts with ATD-20 {corpus_field}")
    for row in coverage_rows:
        raw_class = row.get("raw_class", "")
        validation.require(row.get("required_component_position") == POSITION_REQUIREMENTS.get(raw_class), f"{raw_class}: generic raw class must not imply unsupported position")
        validation.require(row.get("coverage_status") == "unsupported", f"{raw_class}: repository coverage must remain explicitly unsupported")
        validation.require(row.get("pricing_status") == "unavailable", f"{raw_class}: repository pricing must remain unavailable")
        validation.require(row.get("missing_pricing_behavior") == "unavailable", f"{raw_class}: missing pricing must remain unavailable rather than zero")
        validation.require(not row.get("source_id"), f"{raw_class}: unsupported coverage must not name an authorized source")

    placeholder_columns = [
        "schema_version", "reconciliation_version", "class_id", "raw_class", "code_lookup_key",
        "live_placeholder_usd", "import_total_placeholder_usd", "import_annotation_placeholder_usd",
        "values_match", "pricing_evidence_status", "coverage_status", "required_disposition",
    ]
    expected_repository_columns = {
        "source_permission_ledger": source_columns,
        "class_operation_coverage": coverage_columns,
        "placeholder_reconciliation": placeholder_columns,
    }
    validation.require(
        contract.get("repository_table_columns") == expected_repository_columns,
        "contract repository table schemas do not match the validator",
    )
    validation.require(
        contract.get("evidence_package_table_columns") == {
            "source_records": SOURCE_COLUMNS,
            "operation_records": OPERATION_COLUMNS,
            "coverage_matrix": COVERAGE_COLUMNS,
            "review_records": REVIEW_COLUMNS,
        },
        "contract evidence-package table schemas do not match the validator",
    )
    placeholders = read_csv(base / "placeholder_reconciliation.csv", placeholder_columns, validation)
    validation.require(len(placeholders) == 14, "placeholder reconciliation must contain 14 mapped rows")
    placeholder_classes = [row.get("raw_class") for row in sorted(placeholders, key=lambda row: int(row.get("class_id", "-1")))] if placeholders else []
    validation.require(placeholder_classes == RAW_CLASSES, "placeholder reconciliation must use the exact ordered 14 raw classes")
    camera_text = (root / "lib" / "presentation" / "controllers" / "camera_inference_controller.dart").read_text(encoding="utf-8")
    import_text = (root / "lib" / "presentation" / "screens" / "single_image_screen.dart").read_text(encoding="utf-8")
    live_map = extract_dart_price_map(camera_text, "static const Map<String, double> _damagePrices", validation)
    import_map = extract_dart_price_map(import_text, "static const Map<String, double> _priceMap", validation)
    annotation_map = extract_dart_price_map(import_text, "const priceMap =", validation)
    for row in placeholders:
        validation.require(row.get("pricing_evidence_status") == "excluded", f"{row.get('raw_class')}: placeholder must remain excluded from evidence")
        validation.require(row.get("coverage_status") == "unsupported", f"{row.get('raw_class')}: placeholder must not create coverage")
        validation.require(row.get("required_disposition") == "must_not_promote", f"{row.get('raw_class')}: placeholder disposition must prevent promotion")
        expected_match = row.get("live_placeholder_usd") == row.get("import_total_placeholder_usd") == row.get("import_annotation_placeholder_usd")
        validation.require(row.get("values_match") == str(expected_match).lower(), f"{row.get('raw_class')}: placeholder reconciliation mismatch")
        lookup_key = row.get("code_lookup_key", "")
        validation.require(live_map.get(lookup_key) == row.get("live_placeholder_usd"), f"{row.get('raw_class')}: live placeholder does not reconcile to application code")
        validation.require(import_map.get(lookup_key) == row.get("import_total_placeholder_usd"), f"{row.get('raw_class')}: import total placeholder does not reconcile to application code")
        validation.require(annotation_map.get(lookup_key) == row.get("import_annotation_placeholder_usd"), f"{row.get('raw_class')}: import annotation placeholder does not reconcile to application code")
    validation.require("?? 250.0" in camera_text, "live unknown-class fallback no longer reconciles to USD 250")
    validation.require("_priceMap[className] ?? 0" in import_text, "import total unknown-class fallback no longer reconciles to USD 0")
    validation.require("priceMap[className] ?? 250.0" in import_text, "import annotation unknown-class fallback no longer reconciles to USD 250")

    if require_complete:
        completion = contract.get("completion_state") if isinstance(contract.get("completion_state"), dict) else {}
        validation.require(bool(completion.get("authorized_evidence_package")), "authorized evidence package is unavailable")
        validation.require(bool(completion.get("authorized_attainable_route_selected")), "authorized attainable source route is not selected")
        validation.require(bool(completion.get("verified_rights_and_access")), "verified rights and access are unavailable")
        validation.require(bool(completion.get("usable_scoped_sample")), "usable scoped evidence sample is unavailable")
        validation.require(bool(completion.get("product_owner_acceptance")), "product-owner acceptance is unavailable")
        validation.require(bool(completion.get("qualified_appraiser_acceptance")), "qualified Appraiser acceptance is unavailable")
    return validation


def print_result(validation: Validation, success_message: str) -> int:
    if validation.errors:
        for error in validation.errors:
            print(f"ERROR: {error}")
        print(f"FAIL: {len(validation.errors)} validation error(s)")
        return 1
    print(f"PASS: {success_message}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument("--repository-root", type=Path)
    target.add_argument("--package", type=Path)
    parser.add_argument("--require-complete", action="store_true")
    args = parser.parse_args()
    if args.repository_root is not None:
        validation = validate_repository(args.repository_root.resolve(), args.require_complete)
        return print_result(validation, "repository pricing contract validated with exact 14 raw classes")
    validation = validate_package(args.package.resolve(), args.require_complete)
    return print_result(validation, "pricing evidence package validated")


if __name__ == "__main__":
    sys.exit(main())
