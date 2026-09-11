#!/usr/bin/env python3
"""Validate the repository-safe ATD-24 contract or a contextual evidence package."""

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

from phase_one_pricing_validator import (
    RAW_CLASSES,
    validate_repository as validate_phase_one_repository,
)


COUNTRY_CURRENCIES = {"US": "USD", "CA": "CAD"}
STATUS_VALUES = {"verified", "proposed", "unavailable", "permission-required", "excluded"}
PERMISSION_VALUES = {"verified", "permission-required", "unavailable", "excluded"}
COVERAGE_VALUES = {"supported", "unsupported", "unresolved"}
PRICING_VALUES = {"verified", "proposed", "unavailable", "excluded"}
SOURCE_ROUTES = {"repair_shop_records", "commercial_estimating_source", "program_schedule"}
EVIDENCE_TYPES = {"repair_shop_estimate", "completed_invoice", "supplement", "program_schedule", "commercial_estimating_extract", "proposed_assumption", "currency_conversion"}
ESTIMATE_INVOICE_VALUES = {"estimate", "completed_invoice", "program_schedule", "proposed_assumption"}
SUPPLEMENT_VALUES = {"none", "pending", "partial", "final_includes_supplements", "unknown", "not_applicable"}
REGION_RESOLUTIONS = {"zip", "postal_code", "repair_shop", "program", "regional_default"}
RATE_BASES = {"repair_shop", "regional_default", "insurer_program", "employee_wage", "not_applicable"}
RECORD_STATUSES = {"verified", "proposed", "unavailable", "excluded", "not_used"}
LABOR_CATEGORIES = {"body", "paint", "frame", "structural", "mechanical", "glass", "calibration", "other", "unresolved", "not_applicable"}
PARTS_PROVENANCE_VALUES = {"oem", "aftermarket", "recycled", "alternate_oem", "mixed_recorded", "unresolved", "not_applicable"}
MATERIALS_METHODS = {"recorded_line_items", "rate_times_hours", "provider_calculator", "not_applicable", "unresolved"}
AVAILABILITY_VALUES = {"available", "unavailable", "expired", "superseded"}
REFRESH_OUTCOMES = {"no_change", "new_version_available", "corrected_source", "source_unavailable", "expired"}
ID_PATTERN = re.compile(r"^[a-z][a-z0-9-]*$")
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
PACKAGE_FILES = {
    "source_records": "source_records.csv",
    "vehicle_context_records": "vehicle_context_records.csv",
    "region_records": "region_records.csv",
    "contextual_operation_records": "contextual_operation_records.csv",
    "contextual_coverage_matrix": "contextual_coverage_matrix.csv",
    "refresh_recalculation_records": "refresh_recalculation_records.csv",
    "review_records": "review_records.csv",
}


class Validation:
    def __init__(self) -> None:
        self.errors: list[str] = []

    def require(self, condition: bool, message: str) -> None:
        if not condition:
            self.errors.append(message)


def load_json(path: Path, validation: Validation) -> dict[str, object]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        validation.errors.append(f"{path.name}: invalid JSON: {error}")
        return {}
    if not isinstance(value, dict):
        validation.errors.append(f"{path.name}: root must be an object")
        return {}
    return value


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


def valid_id(value: str) -> bool:
    return bool(ID_PATTERN.fullmatch(value))


def read_csv(path: Path, expected_columns: list[str], validation: Validation) -> list[dict[str, str]]:
    try:
        with path.open(newline="", encoding="utf-8") as handle:
            reader = csv.DictReader(handle)
            validation.require((reader.fieldnames or []) == expected_columns, f"{path.name}: required schema fields do not match")
            rows = []
            for line_number, raw_row in enumerate(reader, start=2):
                validation.require(None not in raw_row and all(value is not None for value in raw_row.values()), f"{path.name}:{line_number}: row width does not match schema")
                rows.append({str(key): value or "" for key, value in raw_row.items() if key is not None})
            return rows
    except OSError as error:
        validation.errors.append(f"{path.name}: {error}")
        return []


def contract_path() -> Path:
    return Path(__file__).resolve().parents[1] / "docs" / "research" / "contextual_pricing_evidence" / "contract.json"


def validate_manifest(package: Path, validation: Validation) -> None:
    manifest = load_json(package / "contextual_pricing_manifest.json", validation)
    required = {"schema_version", "package_version", "frozen_at", "hash_algorithm", "manifest_serialization", "access_controlled_location", "coverage_contract_version", "countries", "files"}
    validation.require(set(manifest) == required, "manifest required schema fields do not match")
    validation.require(manifest.get("schema_version") == 1, "manifest schema_version must be 1")
    validation.require(manifest.get("hash_algorithm") == "sha256", "manifest hash_algorithm must be sha256")
    validation.require(manifest.get("manifest_serialization") == "exact_utf8_bytes", "manifest serialization must be exact_utf8_bytes")
    validation.require(manifest.get("countries") == COUNTRY_CURRENCIES, "manifest must keep US/USD and CA/CAD distinct")
    validation.require(bool(manifest.get("access_controlled_location")), "manifest access-controlled location is required")
    validation.require(isinstance(manifest.get("frozen_at"), str) and valid_datetime(str(manifest.get("frozen_at"))), "manifest frozen_at must be an ISO date-time")
    files = manifest.get("files")
    if not isinstance(files, list):
        validation.errors.append("manifest files must be an array")
        return
    roles = [record.get("role") for record in files if isinstance(record, dict)]
    validation.require(Counter(roles) == Counter(PACKAGE_FILES.keys()), "manifest must list each required file role exactly once")
    for record in files:
        if not isinstance(record, dict):
            validation.errors.append("manifest file record must be an object")
            continue
        role = str(record.get("role", ""))
        expected_name = PACKAGE_FILES.get(role)
        validation.require(record.get("path") == expected_name, f"manifest role {role}: invalid path")
        if expected_name is None:
            continue
        path = package / expected_name
        if not path.is_file():
            validation.errors.append(f"manifest file missing: {expected_name}")
            continue
        content = path.read_bytes()
        validation.require(record.get("bytes") == len(content), f"{expected_name}: byte length mismatch")
        validation.require(isinstance(record.get("sha256"), str) and bool(SHA256_PATTERN.fullmatch(str(record.get("sha256")))), f"{expected_name}: invalid sha256")
        validation.require(record.get("sha256") == hashlib.sha256(content).hexdigest(), f"{expected_name}: sha256 mismatch")


def validate_unique_ids(rows: list[dict[str, str]], field: str, validation: Validation) -> dict[str, dict[str, str]]:
    indexed: dict[str, dict[str, str]] = {}
    for row in rows:
        value = row.get(field, "")
        validation.require(valid_id(value), f"{field}: invalid identifier {value!r}")
        validation.require(value not in indexed, f"duplicate {field}: {value}")
        indexed[value] = row
    return indexed


def require_country_currency(row: dict[str, str], record_id: str, validation: Validation) -> None:
    country = row.get("country", "")
    validation.require(country in COUNTRY_CURRENCIES, f"{record_id}: invalid country")
    validation.require(row.get("currency") == COUNTRY_CURRENCIES.get(country), f"{record_id}: country/currency mismatch")


def parse_amount(value: str, record_id: str, field: str, validation: Validation) -> int | None:
    if value == "":
        return None
    try:
        amount = int(value)
    except ValueError:
        validation.errors.append(f"{record_id}: {field} must be an integer minor-unit amount")
        return None
    validation.require(amount >= 0, f"{record_id}: {field} must not be negative")
    return amount


def validate_package(package: Path, require_complete: bool) -> Validation:
    validation = Validation()
    contract = load_json(contract_path(), validation)
    columns = contract.get("evidence_package_table_columns")
    if not isinstance(columns, dict):
        validation.errors.append("contract evidence package schemas are unavailable")
        return validation
    validate_manifest(package, validation)
    tables = {role: read_csv(package / filename, list(columns.get(role, [])), validation) for role, filename in PACKAGE_FILES.items()}
    sources = validate_unique_ids(tables["source_records"], "source_id", validation)
    vehicles = validate_unique_ids(tables["vehicle_context_records"], "vehicle_context_id", validation)
    regions = validate_unique_ids(tables["region_records"], "region_id", validation)
    operations = validate_unique_ids(tables["contextual_operation_records"], "pricing_record_id", validation)
    validate_unique_ids(tables["contextual_coverage_matrix"], "coverage_id", validation)
    validate_unique_ids(tables["refresh_recalculation_records"], "refresh_id", validation)
    validate_unique_ids(tables["review_records"], "review_id", validation)
    permission_fields = {"contractual_entitlement_status", "dataset_rights_status", "record_rights_status", "derived_ranges_permission", "application_display_permission", "device_local_storage_permission", "offline_use_permission", "updates_permission", "retained_revisions_permission", "internal_evaluation_permission", "publication_permission", "redistribution_permission"}
    for source_id, row in sources.items():
        require_country_currency(row, source_id, validation)
        validation.require(row.get("source_route") in SOURCE_ROUTES, f"{source_id}: invalid source route")
        validation.require(row.get("evidence_type") in EVIDENCE_TYPES, f"{source_id}: invalid evidence type")
        validation.require(row.get("estimate_invoice_status") in ESTIMATE_INVOICE_VALUES, f"{source_id}: invalid estimate/invoice status")
        validation.require(row.get("supplement_status") in SUPPLEMENT_VALUES, f"{source_id}: invalid supplement status")
        validation.require(row.get("publisher_claim_status") in STATUS_VALUES, f"{source_id}: invalid publisher claim status")
        for field in permission_fields:
            validation.require(row.get(field) in PERMISSION_VALUES, f"{source_id}: invalid permission status in {field}")
        validation.require(bool(row.get("permission_evidence_reference", "").strip()), f"{source_id}: permission evidence reference is required")
        for field in ("effective_start", "effective_end", "observed_at", "available_at", "expires_at", "refresh_due_at"):
            validation.require(valid_date(row.get(field, "")), f"{source_id}: invalid date in {field}")
        if all(valid_date(row.get(field, "")) for field in ("effective_start", "effective_end", "observed_at", "available_at", "expires_at", "refresh_due_at")):
            start = date.fromisoformat(row["effective_start"])
            end = date.fromisoformat(row["effective_end"])
            observed = date.fromisoformat(row["observed_at"])
            available = date.fromisoformat(row["available_at"])
            expires = date.fromisoformat(row["expires_at"])
            refresh_due = date.fromisoformat(row["refresh_due_at"])
            validation.require(start <= observed <= end <= expires and observed <= available <= expires and available <= refresh_due <= expires, f"{source_id}: source chronology is inconsistent")
    for vehicle_id, row in vehicles.items():
        validation.require(row.get("country") in COUNTRY_CURRENCIES, f"{vehicle_id}: invalid country")
        validation.require(row.get("context_method") in {"manual_confirmed", "vin_prefill_confirmed", "vin_prefill_unconfirmed"}, f"{vehicle_id}: invalid context method")
        if row.get("context_method") == "manual_confirmed":
            validation.require(row.get("manual_confirmation_status") == "confirmed", f"{vehicle_id}: manual vehicle context must be confirmed")
        if row.get("context_method") == "vin_prefill_unconfirmed":
            validation.require(row.get("manual_confirmation_status") != "confirmed", f"{vehicle_id}: unconfirmed VIN prefill cannot imply manual confirmation")
            validation.require(
                row.get("equipment_status") != "confirmed"
                and row.get("exact_fitment_status") != "confirmed_separately"
                and row.get("market_availability_status") != "confirmed_separately",
                f"{vehicle_id}: VIN decoding cannot establish equipment, fitment, or market availability",
            )
    for region_id, row in regions.items():
        require_country_currency(row, region_id, validation)
        validation.require(row.get("region_resolution") in REGION_RESOLUTIONS, f"{region_id}: invalid region resolution")
        validation.require(row.get("rate_basis") in RATE_BASES, f"{region_id}: invalid rate basis")
        for field in ("repair_shop_rate_status", "regional_default_status", "insurer_program_schedule_status", "employee_wage_status"):
            validation.require(row.get(field) in RECORD_STATUSES, f"{region_id}: invalid status in {field}")
        validation.require(row.get("availability_status") in AVAILABILITY_VALUES, f"{region_id}: invalid availability status")
        source = sources.get(row.get("source_id", ""))
        validation.require(source is not None, f"{region_id}: unknown source_id")
        if source:
            validation.require(row.get("source_version") == source.get("source_version"), f"{region_id}: source-version mismatch")
            validation.require(row.get("country") == source.get("country") and row.get("currency") == source.get("currency"), f"{region_id}: source geography mismatch")
        status_field = {
            "repair_shop": "repair_shop_rate_status",
            "regional_default": "regional_default_status",
            "insurer_program": "insurer_program_schedule_status",
            "employee_wage": "employee_wage_status",
        }.get(row.get("rate_basis", ""))
        if status_field:
            validation.require(row.get(status_field) == "verified", f"{region_id}: rate basis status is inconsistent")
        if row.get("rate_basis") != "insurer_program":
            validation.require(row.get("insurer_program_schedule_status") != "verified", f"{region_id}: program schedule cannot create retail regional coverage")
        if row.get("rate_basis") != "employee_wage":
            validation.require(row.get("employee_wage_status") != "verified", f"{region_id}: employee wages cannot be treated as customer billing rates")
    conflict_keys: set[tuple[str, ...]] = set()
    shared_groups: defaultdict[str, list[str]] = defaultdict(list)
    for pricing_id, row in operations.items():
        require_country_currency(row, pricing_id, validation)
        validation.require(row.get("raw_class") in RAW_CLASSES, f"{pricing_id}: unknown raw class")
        validation.require(row.get("source_id") in sources, f"{pricing_id}: unknown source_id")
        validation.require(row.get("vehicle_context_id") in vehicles, f"{pricing_id}: unknown vehicle context")
        validation.require(row.get("region_id") in regions, f"{pricing_id}: unknown region")
        source = sources.get(row.get("source_id", ""), {})
        vehicle = vehicles.get(row.get("vehicle_context_id", ""), {})
        region = regions.get(row.get("region_id", ""), {})
        validation.require(row.get("source_version") == source.get("source_version"), f"{pricing_id}: source-version mismatch")
        validation.require(row.get("country") == source.get("country") and row.get("currency") == source.get("currency"), f"{pricing_id}: source country/currency mismatch")
        validation.require(row.get("country") == vehicle.get("country"), f"{pricing_id}: vehicle context country mismatch")
        validation.require(row.get("country") == region.get("country") and row.get("currency") == region.get("currency"), f"{pricing_id}: region country/currency mismatch")
        validation.require(row.get("pricing_status") in PRICING_VALUES, f"{pricing_id}: invalid pricing status")
        validation.require(row.get("labor_category") in LABOR_CATEGORIES, f"{pricing_id}: invalid labor category")
        validation.require(row.get("parts_provenance") in PARTS_PROVENANCE_VALUES, f"{pricing_id}: invalid parts provenance")
        validation.require(row.get("materials_method") in MATERIALS_METHODS, f"{pricing_id}: invalid materials method")
        validation.require(row.get("evidence_type") in EVIDENCE_TYPES, f"{pricing_id}: invalid evidence type")
        validation.require(row.get("estimate_invoice_status") in ESTIMATE_INVOICE_VALUES, f"{pricing_id}: invalid estimate/invoice status")
        validation.require(row.get("supplement_status") in SUPPLEMENT_VALUES, f"{pricing_id}: invalid supplement status")
        validation.require(row.get("evidence_type") == source.get("evidence_type"), f"{pricing_id}: evidence_type is inconsistent with source")
        validation.require(row.get("estimate_invoice_status") == source.get("estimate_invoice_status"), f"{pricing_id}: estimate/invoice status is inconsistent with source")
        validation.require(row.get("supplement_status") == source.get("supplement_status"), f"{pricing_id}: supplement status is inconsistent with source")
        minimum = parse_amount(row.get("minimum_amount_minor", ""), pricing_id, "minimum_amount_minor", validation)
        maximum = parse_amount(row.get("maximum_amount_minor", ""), pricing_id, "maximum_amount_minor", validation)
        if row.get("pricing_status") == "unavailable":
            validation.require(minimum is None and maximum is None, f"{pricing_id}: unavailable pricing must not contain amounts")
        if row.get("pricing_status") == "verified":
            validation.require(minimum is not None and maximum is not None, f"{pricing_id}: verified pricing requires both amounts")
            if minimum is not None and maximum is not None:
                validation.require(minimum <= maximum, f"{pricing_id}: minimum exceeds maximum")
        validation.require(not (row.get("evidence_type") == "currency_conversion" and row.get("pricing_status") == "verified"), f"{pricing_id}: currency conversion cannot create regional coverage")
        validation.require(not (row.get("evidence_type") == "proposed_assumption" and row.get("pricing_status") == "verified"), f"{pricing_id}: proposed assumptions cannot be verified pricing")
        for field in ("quote_observed_at", "available_at", "expires_at"):
            validation.require(valid_date(row.get(field, "")), f"{pricing_id}: invalid date in {field}")
        if all(valid_date(row.get(field, "")) for field in ("quote_observed_at", "available_at", "expires_at")):
            observed = date.fromisoformat(row["quote_observed_at"])
            available = date.fromisoformat(row["available_at"])
            expires = date.fromisoformat(row["expires_at"])
            if observed > expires or available > expires:
                validation.require(row.get("pricing_status") == "unavailable" and minimum is None and maximum is None, f"{pricing_id}: expired or stale pricing must remain unavailable")
        key = tuple(row.get(field, "") for field in ("source_id", "source_version", "vehicle_context_id", "region_id", "raw_class", "component_id", "exact_component_position", "damage_type", "repair_operation_id", "labor_category", "parts_provenance", "materials_method", "evidence_type", "estimate_invoice_status", "supplement_status", "quote_observed_at"))
        if key in conflict_keys:
            validation.errors.append(f"{pricing_id}: conflicting contextual pricing records")
        conflict_keys.add(key)
        shared_groups[row.get("shared_operation_group_id", "")].append(pricing_id)
    for group_id, record_ids in shared_groups.items():
        if group_id and len(record_ids) > 1:
            validation.errors.append(f"{group_id}: shared operation group counted more than once: {', '.join(record_ids)}")
    for row in tables["contextual_coverage_matrix"]:
        coverage_id = row.get("coverage_id", "")
        require_country_currency(row, coverage_id, validation)
        validation.require(row.get("raw_class") in RAW_CLASSES, f"{coverage_id}: unknown raw class")
        validation.require(row.get("coverage_status") in COVERAGE_VALUES, f"{coverage_id}: invalid coverage status")
        validation.require(row.get("pricing_status") in PRICING_VALUES, f"{coverage_id}: invalid pricing status")
        validation.require(row.get("missing_pricing_behavior") == "unavailable", f"{coverage_id}: missing pricing must remain unavailable")
        dimension_pairs = (
            ("country", "country"),
            ("currency", "currency"),
            ("region_id", "region_id"),
            ("vehicle_context_id", "vehicle_context_id"),
            ("raw_class", "raw_class"),
            ("exact_component_position", "exact_component_position"),
            ("damage_type", "damage_type"),
            ("repair_operation_id", "repair_operation_id"),
            ("labor_category", "labor_category"),
            ("parts_provenance", "parts_provenance"),
            ("materials_method", "materials_method"),
            ("source_id", "source_id"),
            ("source_version", "source_version"),
            ("effective_or_observation_date", "quote_observed_at"),
        )
        matches = [
            item
            for item in operations.values()
            if all(row.get(coverage_field) == item.get(operation_field) for coverage_field, operation_field in dimension_pairs)
        ]
        if row.get("coverage_status") == "supported":
            validation.require(len(matches) == 1, f"{coverage_id}: supported coverage does not reconcile all contextual dimensions")
            validation.require(row.get("pricing_status") == "verified" and len(matches) == 1 and matches[0].get("pricing_status") == "verified", f"{coverage_id}: supported coverage requires one verified contextual pricing record")
        else:
            validation.require(bool(row.get("unresolved_reason", "").strip()), f"{coverage_id}: unsupported or unresolved coverage requires a reason")
            validation.require(row.get("pricing_status") != "verified", f"{coverage_id}: unsupported coverage cannot claim verified pricing")
    for row in tables["refresh_recalculation_records"]:
        refresh_id = row.get("refresh_id", "")
        validation.require(row.get("source_id") in sources, f"{refresh_id}: unknown source_id")
        validation.require(valid_date(row.get("checked_at", "")), f"{refresh_id}: invalid checked_at")
        validation.require(row.get("refresh_outcome") in REFRESH_OUTCOMES, f"{refresh_id}: invalid refresh outcome")
        validation.require(row.get("draft_recalculation_status") == "required_explicitly", f"{refresh_id}: draft recalculation must be explicit")
        validation.require(row.get("completed_revision_status") == "retained_unchanged", f"{refresh_id}: completed revisions must remain frozen")
        validation.require(row.get("currency_conversion_used") == "false", f"{refresh_id}: currency conversion cannot create or refresh coverage")
    for row in tables["review_records"]:
        validation.require(row.get("reviewer_role") in {"appraiser", "product_owner"}, f"{row.get('review_id')}: invalid reviewer role")
        validation.require(row.get("decision") in {"accepted", "rejected", "needs_revision"}, f"{row.get('review_id')}: invalid review decision")
        validation.require(valid_date(row.get("reviewed_at", "")), f"{row.get('review_id')}: invalid reviewed_at")
        validation.require(bool(row.get("rationale", "").strip()), f"{row.get('review_id')}: rationale is required")
        if row.get("reviewer_role") == "appraiser" and row.get("decision") == "accepted":
            validation.require(row.get("reviewer_qualification_status") == "verified", f"{row.get('review_id')}: accepted Appraiser review requires verified qualification")
    if require_complete:
        critical_permissions = {
            "contractual_entitlement_status",
            "dataset_rights_status",
            "record_rights_status",
            "derived_ranges_permission",
            "application_display_permission",
            "device_local_storage_permission",
            "offline_use_permission",
            "updates_permission",
            "retained_revisions_permission",
            "internal_evaluation_permission",
        }
        for country, currency in COUNTRY_CURRENCIES.items():
            country_sources = [row for row in sources.values() if row.get("country") == country and row.get("currency") == currency]
            validation.require(bool(country_sources) and all(all(row.get(field) == "verified" for field in critical_permissions) for row in country_sources), f"complete package requires authorized rights and access in {country}/{currency}")
            supported_classes = {
                row.get("raw_class")
                for row in tables["contextual_coverage_matrix"]
                if row.get("country") == country
                and row.get("currency") == currency
                and row.get("coverage_status") == "supported"
                and row.get("pricing_status") == "verified"
            }
            validation.require(supported_classes == set(RAW_CLASSES), f"complete package requires all 14 supported classes in {country}/{currency} or an approved product-scope revision")
            accepted_appraiser_records = {
                row.get("record_id")
                for row in tables["review_records"]
                if row.get("reviewer_role") == "appraiser"
                and row.get("reviewer_qualification_status") == "verified"
                and row.get("decision") == "accepted"
            }
            accepted_owner_records = {
                row.get("record_id")
                for row in tables["review_records"]
                if row.get("reviewer_role") == "product_owner"
                and row.get("decision") == "accepted"
            }
            country_pricing_ids = {key for key, row in operations.items() if row.get("country") == country}
            country_coverage_ids = {row.get("coverage_id") for row in tables["contextual_coverage_matrix"] if row.get("country") == country}
            validation.require(bool(country_pricing_ids & accepted_appraiser_records), f"complete package requires qualified Appraiser acceptance in {country}/{currency}")
            validation.require(bool(country_coverage_ids & accepted_owner_records), f"complete package requires product-owner acceptance in {country}/{currency}")
    return validation


def validate_repository(root: Path, require_complete: bool) -> Validation:
    validation = Validation()
    base = root / "docs" / "research" / "contextual_pricing_evidence"
    contract = load_json(base / "contract.json", validation)
    validation.require(contract.get("countries") == COUNTRY_CURRENCIES, "contract must keep US/USD and CA/CAD distinct")
    validation.require(contract.get("required_raw_classes") == RAW_CLASSES, "contract must reuse the exact ordered 14 raw classes")
    phase_one_validation = validate_phase_one_repository(root, False)
    for error in phase_one_validation.errors:
        validation.errors.append(f"ATD-20/ATD-22 consistency: {error}")
    ledger_rows = read_csv(
        base / "source_permission_ledger.csv",
        list(contract.get("repository_ledger_columns", [])),
        validation,
    )
    validation.require(len(ledger_rows) == 8, "source permission ledger must contain 8 candidate routes")
    validate_unique_ids(ledger_rows, "source_id", validation)
    for row in ledger_rows:
        source_id = row.get("source_id", "")
        require_country_currency(row, source_id, validation)
        validation.require(row.get("publisher_claim_status") in STATUS_VALUES, f"{source_id}: invalid publisher claim status")
        if row.get("publisher_claim_status") == "verified":
            validation.require(bool(row.get("publisher_claim_evidence_uri", "").strip()), f"{source_id}: verified publisher claim requires evidence URI")
        for field in (
            "contractual_entitlement_status",
            "dataset_rights_status",
            "record_rights_status",
            "derived_ranges_permission",
            "application_display_permission",
            "device_local_storage_permission",
            "offline_use_permission",
            "updates_permission",
            "retained_revisions_permission",
            "internal_evaluation_permission",
            "publication_permission",
            "redistribution_permission",
        ):
            validation.require(row.get(field) in PERMISSION_VALUES, f"{source_id}: invalid permission status in {field}")
        validation.require(row.get("evidence_status") in STATUS_VALUES, f"{source_id}: invalid evidence status")
        validation.require(row.get("coverage_eligibility") == "excluded", f"{source_id}: candidate route must remain excluded")
        validation.require(row.get("source_version") == "unavailable", f"{source_id}: no source version may be implied")
        validation.require(bool(row.get("unresolved_requirements", "").strip()), f"{source_id}: unresolved requirements are required")
    rows = read_csv(base / "contextual_coverage_matrix.csv", list(contract.get("repository_coverage_columns", [])), validation)
    validation.require(len(rows) == 28, "contextual coverage matrix must contain 28 country/class rows")
    for country, currency in COUNTRY_CURRENCIES.items():
        country_rows = [row for row in rows if row.get("country") == country]
        validation.require([row.get("raw_class") for row in country_rows] == RAW_CLASSES, f"{country}: contextual matrix must contain the exact ordered 14 raw classes")
        for row in country_rows:
            coverage_id = row.get("coverage_id", "")
            validation.require(row.get("currency") == currency, f"{coverage_id}: country/currency mismatch")
            validation.require(row.get("coverage_status") == "unsupported" and row.get("pricing_status") == "unavailable", f"{coverage_id}: repository coverage must remain unsupported and unavailable")
            validation.require(row.get("missing_pricing_behavior") == "unavailable", f"{coverage_id}: missing pricing must remain unavailable")
            validation.require(row.get("source_id") == "unavailable" and row.get("source_version") == "unavailable", f"{coverage_id}: no authorized source or version may be implied")
            validation.require(bool(row.get("unresolved_requirements", "").strip()), f"{coverage_id}: unresolved requirements are required")
    if require_complete:
        completion = contract.get("completion_state")
        if isinstance(completion, dict):
            for key, value in completion.items():
                if key != "status":
                    validation.require(bool(value), f"completion requirement unavailable: {key}")
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
        return print_result(validation, "28 unsupported contextual coverage rows across US/USD and CA/CAD; 8 excluded candidate routes validated")
    validation = validate_package(args.package.resolve(), args.require_complete)
    return print_result(validation, "contextual pricing evidence package validated")


if __name__ == "__main__":
    sys.exit(main())
