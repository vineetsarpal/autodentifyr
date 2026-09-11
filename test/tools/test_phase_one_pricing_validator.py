import csv
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
VALIDATOR = REPOSITORY_ROOT / "tool" / "phase_one_pricing_validator.py"


class PhaseOnePricingValidatorTest(unittest.TestCase):
    def run_validator(self, package: Path, *extra_args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(VALIDATOR), "--package", str(package), *extra_args],
            cwd=REPOSITORY_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

    def write_csv(self, path: Path, fieldnames: list[str], rows: list[dict[str, object]]) -> None:
        with path.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(rows)

    def create_package(self, root: Path) -> Path:
        package = root / "pricing-package"
        package.mkdir()

        source_fields = [
            "source_id", "source_owner", "source_name", "source_version",
            "collection_period_start", "collection_period_end", "geography",
            "currency", "evidence_type", "estimate_invoice_status",
            "supplement_status", "parts_basis", "labor_categories",
            "materials_basis", "inclusions", "exclusions", "refresh_date",
            "publisher_claim_status", "contractual_entitlement_status",
            "dataset_rights_status", "record_rights_status",
            "derived_ranges_permission", "application_display_permission",
            "device_local_storage_permission", "offline_use_permission",
            "updates_permission", "retained_revisions_permission",
            "internal_evaluation_permission", "publication_permission",
            "redistribution_permission", "permission_evidence_reference",
        ]
        self.write_csv(
            package / "source_records.csv",
            source_fields,
            [{
                "source_id": "src-shop-2026q2", "source_owner": "Example repair shop",
                "source_name": "Authorized completed records", "source_version": "2026q2-v1",
                "collection_period_start": "2026-04-01", "collection_period_end": "2026-06-30",
                "geography": "US", "currency": "USD", "evidence_type": "repair_shop_records",
                "estimate_invoice_status": "completed_invoice", "supplement_status": "final_includes_supplements",
                "parts_basis": "mixed_recorded", "labor_categories": "body;paint",
                "materials_basis": "recorded", "inclusions": "recorded line items",
                "exclusions": "tax", "refresh_date": "2026-07-15",
                "publisher_claim_status": "verified", "contractual_entitlement_status": "verified",
                "dataset_rights_status": "verified", "record_rights_status": "verified",
                "derived_ranges_permission": "verified", "application_display_permission": "verified",
                "device_local_storage_permission": "verified", "offline_use_permission": "verified",
                "updates_permission": "verified", "retained_revisions_permission": "verified",
                "internal_evaluation_permission": "verified", "publication_permission": "excluded",
                "redistribution_permission": "excluded", "permission_evidence_reference": "acl://permissions/src-shop-2026q2",
            }],
        )

        operation_fields = [
            "pricing_record_id", "source_id", "source_version", "cohort_id",
            "repair_operation_id", "shared_operation_group_id", "component_id",
            "damage_type", "vehicle_context", "geography", "currency",
            "evidence_type", "estimate_invoice_status", "supplement_status",
            "minimum_amount_minor", "maximum_amount_minor", "pricing_status",
            "included_operation_ids", "exclusions", "observed_at",
        ]
        self.write_csv(
            package / "operation_records.csv",
            operation_fields,
            [{
                "pricing_record_id": "pr-0001", "source_id": "src-shop-2026q2",
                "source_version": "2026q2-v1", "cohort_id": "cohort-front-windscreen-replace",
                "repair_operation_id": "op-front-windscreen-replace",
                "shared_operation_group_id": "shared-glass-front-0001",
                "component_id": "front_windscreen", "damage_type": "unspecified_visible_damage",
                "vehicle_context": "phase1_us_baseline", "geography": "US", "currency": "USD",
                "evidence_type": "repair_shop_records", "estimate_invoice_status": "completed_invoice",
                "supplement_status": "final_includes_supplements", "minimum_amount_minor": "40000",
                "maximum_amount_minor": "65000", "pricing_status": "verified",
                "included_operation_ids": "op-glass-labor", "exclusions": "tax", "observed_at": "2026-06-15",
            }],
        )

        coverage_fields = [
            "coverage_id", "raw_class", "component_family", "required_component_position",
            "damage_type", "cohort_id", "repair_operation_id", "vehicle_context",
            "geography", "currency", "source_id", "coverage_status",
            "pricing_status", "missing_pricing_behavior", "unresolved_reason",
        ]
        self.write_csv(
            package / "coverage_matrix.csv",
            coverage_fields,
            [{
                "coverage_id": "cov-front-windscreen-replace", "raw_class": "Front-windscreen-damage",
                "component_family": "front_windscreen", "required_component_position": "none",
                "damage_type": "unspecified_visible_damage", "cohort_id": "cohort-front-windscreen-replace",
                "repair_operation_id": "op-front-windscreen-replace", "vehicle_context": "phase1_us_baseline",
                "geography": "US", "currency": "USD", "source_id": "src-shop-2026q2",
                "coverage_status": "supported", "pricing_status": "verified",
                "missing_pricing_behavior": "unavailable", "unresolved_reason": "",
            }],
        )

        review_fields = [
            "review_id", "review_type", "record_id", "reviewer_role",
            "reviewer_id", "decision", "reviewed_at", "rationale",
        ]
        self.write_csv(
            package / "review_records.csv",
            review_fields,
            [
                {"review_id": "rev-appraiser-1", "review_type": "operation_scope", "record_id": "pr-0001", "reviewer_role": "appraiser", "reviewer_id": "appraiser-001", "decision": "accepted", "reviewed_at": "2026-07-20", "rationale": "Scope reviewed."},
                {"review_id": "rev-owner-1", "review_type": "product_scope", "record_id": "cohort-front-windscreen-replace", "reviewer_role": "product_owner", "reviewer_id": "owner-001", "decision": "accepted", "reviewed_at": "2026-07-20", "rationale": "Coverage accepted."},
            ],
        )

        files = []
        for role, filename in [
            ("source_records", "source_records.csv"),
            ("operation_records", "operation_records.csv"),
            ("coverage_matrix", "coverage_matrix.csv"),
            ("review_records", "review_records.csv"),
        ]:
            content = (package / filename).read_bytes()
            files.append({"role": role, "path": filename, "bytes": len(content), "sha256": hashlib.sha256(content).hexdigest()})
        manifest = {
            "schema_version": 1,
            "package_version": "2026q2-v1",
            "frozen_at": "2026-07-20T12:00:00Z",
            "hash_algorithm": "sha256",
            "manifest_serialization": "exact_utf8_bytes",
            "access_controlled_location": "acl://pricing/2026q2-v1",
            "geography": "US",
            "currency": "USD",
            "coverage_contract_version": "1",
            "files": files,
        }
        (package / "pricing_manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        return package

    def test_valid_scoped_package_passes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_validator(self.create_package(Path(directory)))
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn("PASS", result.stdout)

    def test_manifest_hash_and_byte_length_are_verified(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = self.create_package(Path(directory))
            with (package / "coverage_matrix.csv").open("a", encoding="utf-8") as handle:
                handle.write("tampered\n")
            result = self.run_validator(package)
        self.assertNotEqual(0, result.returncode)
        self.assertIn("byte length", result.stdout)
        self.assertIn("sha256", result.stdout)

    def test_missing_pricing_cannot_be_zero_or_claim_supported(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = self.create_package(Path(directory))
            with (package / "operation_records.csv").open(encoding="utf-8") as handle:
                rows = list(csv.DictReader(handle))
            rows[0]["pricing_status"] = "unavailable"
            rows[0]["minimum_amount_minor"] = "0"
            rows[0]["maximum_amount_minor"] = "0"
            self.write_csv(package / "operation_records.csv", list(rows[0]), rows)
            self.refresh_manifest(package, "operation_records.csv")
            result = self.run_validator(package)
        self.assertNotEqual(0, result.returncode)
        self.assertIn("unavailable pricing must not contain amounts", result.stdout)
        self.assertIn("supported coverage requires verified pricing", result.stdout)

    def test_duplicate_and_conflicting_pricing_records_fail(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = self.create_package(Path(directory))
            path = package / "operation_records.csv"
            with path.open(encoding="utf-8") as handle:
                rows = list(csv.DictReader(handle))
            duplicate = dict(rows[0])
            duplicate["pricing_record_id"] = "pr-0002"
            duplicate["maximum_amount_minor"] = "70000"
            self.write_csv(path, list(rows[0]), rows + [duplicate])
            self.refresh_manifest(package, "operation_records.csv")
            result = self.run_validator(package)
        self.assertNotEqual(0, result.returncode)
        self.assertIn("conflicting pricing records", result.stdout)

    def test_shared_operation_cannot_be_counted_twice(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = self.create_package(Path(directory))
            path = package / "operation_records.csv"
            with path.open(encoding="utf-8") as handle:
                rows = list(csv.DictReader(handle))
            duplicate = dict(rows[0])
            duplicate["pricing_record_id"] = "pr-0002"
            duplicate["cohort_id"] = "cohort-door-refinish"
            duplicate["repair_operation_id"] = "op-door-refinish"
            self.write_csv(path, list(rows[0]), rows + [duplicate])
            self.refresh_manifest(package, "operation_records.csv")
            result = self.run_validator(package)
        self.assertNotEqual(0, result.returncode)
        self.assertIn("shared operation group counted more than once", result.stdout)

    def test_estimates_invoices_supplements_and_assumptions_are_not_conflated(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = self.create_package(Path(directory))
            path = package / "operation_records.csv"
            with path.open(encoding="utf-8") as handle:
                rows = list(csv.DictReader(handle))
            rows[0]["estimate_invoice_status"] = "proposed_assumption"
            rows[0]["pricing_status"] = "verified"
            self.write_csv(path, list(rows[0]), rows)
            self.refresh_manifest(package, "operation_records.csv")
            result = self.run_validator(package)
        self.assertNotEqual(0, result.returncode)
        self.assertIn("proposed assumptions cannot be verified pricing", result.stdout)

    def test_source_permissions_and_identifiers_are_complete_and_controlled(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = self.create_package(Path(directory))
            path = package / "source_records.csv"
            with path.open(encoding="utf-8") as handle:
                rows = list(csv.DictReader(handle))
            rows[0]["source_id"] = "Invalid source id"
            rows[0]["offline_use_permission"] = "maybe"
            rows[0]["permission_evidence_reference"] = ""
            self.write_csv(path, list(rows[0]), rows)
            self.refresh_manifest(package, "source_records.csv")
            result = self.run_validator(package)
        self.assertNotEqual(0, result.returncode)
        self.assertIn("invalid identifier", result.stdout)
        self.assertIn("invalid permission status", result.stdout)
        self.assertIn("permission_evidence_reference is blank", result.stdout)

    def test_source_version_geography_currency_and_dates_must_reconcile(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = self.create_package(Path(directory))
            source_path = package / "source_records.csv"
            with source_path.open(encoding="utf-8") as handle:
                source_rows = list(csv.DictReader(handle))
            source_rows[0]["collection_period_end"] = "2026-03-31"
            self.write_csv(source_path, list(source_rows[0]), source_rows)
            self.refresh_manifest(package, "source_records.csv")
            operation_path = package / "operation_records.csv"
            with operation_path.open(encoding="utf-8") as handle:
                operation_rows = list(csv.DictReader(handle))
            operation_rows[0]["source_version"] = "wrong-version"
            operation_rows[0]["currency"] = "CAD"
            self.write_csv(operation_path, list(operation_rows[0]), operation_rows)
            self.refresh_manifest(package, "operation_records.csv")
            result = self.run_validator(package)
        self.assertNotEqual(0, result.returncode)
        self.assertIn("collection period and refresh date are inconsistent", result.stdout)
        self.assertIn("source-version mismatch", result.stdout)
        self.assertIn("currency", result.stdout)

    def test_unsupported_coverage_requires_reason_and_cannot_claim_verified_pricing(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = self.create_package(Path(directory))
            path = package / "coverage_matrix.csv"
            with path.open(encoding="utf-8") as handle:
                rows = list(csv.DictReader(handle))
            rows[0]["coverage_status"] = "unsupported"
            rows[0]["pricing_status"] = "verified"
            rows[0]["unresolved_reason"] = ""
            self.write_csv(path, list(rows[0]), rows)
            self.refresh_manifest(package, "coverage_matrix.csv")
            result = self.run_validator(package)
        self.assertNotEqual(0, result.returncode)
        self.assertIn("unsupported or unresolved coverage requires a reason", result.stdout)
        self.assertIn("unsupported cohorts must not claim verified pricing", result.stdout)

    def test_repository_contract_has_exact_fourteen_class_mapping(self) -> None:
        result = subprocess.run(
            [sys.executable, str(VALIDATOR), "--repository-root", str(REPOSITORY_ROOT)],
            cwd=REPOSITORY_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn("14 raw classes", result.stdout)

    def test_completion_gate_fails_for_repository_scaffolding(self) -> None:
        result = subprocess.run(
            [sys.executable, str(VALIDATOR), "--repository-root", str(REPOSITORY_ROOT), "--require-complete"],
            cwd=REPOSITORY_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(0, result.returncode)
        self.assertIn("authorized evidence package is unavailable", result.stdout)

    def refresh_manifest(self, package: Path, filename: str) -> None:
        manifest_path = package / "pricing_manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        content = (package / filename).read_bytes()
        for record in manifest["files"]:
            if record["path"] == filename:
                record["bytes"] = len(content)
                record["sha256"] = hashlib.sha256(content).hexdigest()
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")


if __name__ == "__main__":
    unittest.main()
