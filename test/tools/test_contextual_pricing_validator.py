import csv
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
VALIDATOR = REPOSITORY_ROOT / "tool" / "contextual_pricing_validator.py"


class ContextualPricingValidatorTest(unittest.TestCase):
    def run_package_validator(
        self, package: Path, *extra_args: str
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(VALIDATOR), "--package", str(package), *extra_args],
            cwd=REPOSITORY_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

    def write_csv(self, path: Path, rows: list[dict[str, str]]) -> None:
        with path.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)

    def create_package(self, root: Path) -> Path:
        package = root / "contextual-pricing-package"
        package.mkdir()
        sources = []
        vehicles = []
        regions = []
        operations = []
        coverage = []
        refreshes = []
        reviews = []
        for country, currency, region_resolution in (
            ("US", "USD", "zip"),
            ("CA", "CAD", "postal_code"),
        ):
            suffix = country.lower()
            source_id = f"src-shop-{suffix}"
            source_version = "2026q2-v1"
            vehicle_id = f"vehicle-context-{suffix}"
            region_id = f"region-{suffix}"
            pricing_id = f"pricing-{suffix}"
            sources.append(
                {
                    "source_id": source_id,
                    "source_owner": "Synthetic Repair Shop",
                    "source_name": "Synthetic authorized records",
                    "source_version": source_version,
                    "source_route": "repair_shop_records",
                    "country": country,
                    "currency": currency,
                    "evidence_type": "completed_invoice",
                    "estimate_invoice_status": "completed_invoice",
                    "supplement_status": "final_includes_supplements",
                    "effective_start": "2026-04-01",
                    "effective_end": "2026-06-30",
                    "observed_at": "2026-06-15",
                    "available_at": "2026-06-15",
                    "expires_at": "2026-12-31",
                    "supersedes_source_version": "none",
                    "corrected_at": "none",
                    "refresh_due_at": "2026-10-01",
                    "update_cadence": "quarterly_review",
                    "publisher_claim_status": "verified",
                    "contractual_entitlement_status": "verified",
                    "dataset_rights_status": "verified",
                    "record_rights_status": "verified",
                    "derived_ranges_permission": "verified",
                    "application_display_permission": "verified",
                    "device_local_storage_permission": "verified",
                    "offline_use_permission": "verified",
                    "updates_permission": "verified",
                    "retained_revisions_permission": "verified",
                    "internal_evaluation_permission": "verified",
                    "publication_permission": "excluded",
                    "redistribution_permission": "excluded",
                    "permission_evidence_reference": f"acl://permissions/{source_id}",
                }
            )
            vehicles.append(
                {
                    "vehicle_context_id": vehicle_id,
                    "context_method": "manual_confirmed",
                    "country": country,
                    "model_year": "2024",
                    "make": "Synthetic Make",
                    "model": "Synthetic Model",
                    "body_style": "sedan",
                    "equipment_status": "confirmed",
                    "manual_confirmation_status": "confirmed",
                    "confirmed_at": "2026-07-01",
                    "vin_prefill_source_id": "none",
                    "vin_prefill_status": "not_used",
                    "exact_fitment_status": "confirmed_separately",
                    "market_availability_status": "confirmed_separately",
                }
            )
            regions.append(
                {
                    "region_id": region_id,
                    "country": country,
                    "currency": currency,
                    "region_resolution": region_resolution,
                    "region_basis": f"synthetic-{suffix}-region",
                    "rate_basis": "repair_shop",
                    "repair_shop_rate_status": "verified",
                    "regional_default_status": "not_used",
                    "insurer_program_schedule_status": "not_used",
                    "employee_wage_status": "excluded",
                    "source_id": source_id,
                    "source_version": source_version,
                    "effective_date": "2026-04-01",
                    "observed_at": "2026-06-15",
                    "expires_at": "2026-12-31",
                    "availability_status": "available",
                    "inclusions": "body billing rate",
                    "exclusions": "tax",
                }
            )
            operations.append(
                {
                    "pricing_record_id": pricing_id,
                    "source_id": source_id,
                    "source_version": source_version,
                    "vehicle_context_id": vehicle_id,
                    "region_id": region_id,
                    "raw_class": "Front-windscreen-damage",
                    "component_id": "front-windscreen",
                    "exact_component_position": "front_windscreen",
                    "damage_type": "unspecified_visible_damage",
                    "repair_operation_id": "glass-replacement",
                    "shared_operation_group_id": f"shared-glass-{suffix}",
                    "labor_category": "glass",
                    "operation_hours": "1.5",
                    "operation_hours_status": "verified",
                    "parts_provenance": "oem",
                    "parts_fitment_status": "confirmed_separately",
                    "materials_method": "recorded_line_items",
                    "country": country,
                    "currency": currency,
                    "evidence_type": "completed_invoice",
                    "estimate_invoice_status": "completed_invoice",
                    "supplement_status": "final_includes_supplements",
                    "minimum_amount_minor": "40000",
                    "maximum_amount_minor": "65000",
                    "pricing_status": "verified",
                    "quote_observed_at": "2026-06-15",
                    "available_at": "2026-06-15",
                    "expires_at": "2026-12-31",
                    "supersedes_pricing_record_id": "none",
                    "included_operation_ids": "glass-labor",
                    "tax_status": "excluded",
                    "fees_status": "excluded",
                    "freight_status": "recorded",
                    "discount_status": "recorded",
                    "exclusions": "tax",
                }
            )
            coverage.append(
                {
                    "coverage_id": f"coverage-{suffix}",
                    "country": country,
                    "currency": currency,
                    "region_id": region_id,
                    "vehicle_context_id": vehicle_id,
                    "raw_class": "Front-windscreen-damage",
                    "exact_component_position": "front_windscreen",
                    "damage_type": "unspecified_visible_damage",
                    "repair_operation_id": "glass-replacement",
                    "labor_category": "glass",
                    "parts_provenance": "oem",
                    "materials_method": "recorded_line_items",
                    "source_id": source_id,
                    "source_version": source_version,
                    "effective_or_observation_date": "2026-06-15",
                    "coverage_status": "supported",
                    "pricing_status": "verified",
                    "missing_pricing_behavior": "unavailable",
                    "unresolved_reason": "",
                }
            )
            refreshes.append(
                {
                    "refresh_id": f"refresh-{suffix}",
                    "source_id": source_id,
                    "prior_source_version": "2026q1-v1",
                    "new_source_version": source_version,
                    "checked_at": "2026-07-01",
                    "refresh_outcome": "new_version_available",
                    "stale_status": "current",
                    "corrected_rate_status": "none",
                    "availability_change_status": "none",
                    "draft_recalculation_status": "required_explicitly",
                    "completed_revision_status": "retained_unchanged",
                    "currency_conversion_used": "false",
                    "rationale": "Synthetic refresh record.",
                }
            )
            reviews.extend(
                [
                    {
                        "review_id": f"review-appraiser-{suffix}",
                        "review_type": "contextual_qualification",
                        "record_id": pricing_id,
                        "reviewer_role": "appraiser",
                        "reviewer_id": f"appraiser-{suffix}",
                        "reviewer_qualification_status": "verified",
                        "decision": "accepted",
                        "reviewed_at": "2026-07-02",
                        "rationale": "Synthetic scope review.",
                    },
                    {
                        "review_id": f"review-owner-{suffix}",
                        "review_type": "product_scope",
                        "record_id": f"coverage-{suffix}",
                        "reviewer_role": "product_owner",
                        "reviewer_id": "owner-1",
                        "reviewer_qualification_status": "not_applicable",
                        "decision": "accepted",
                        "reviewed_at": "2026-07-02",
                        "rationale": "Synthetic coverage review.",
                    },
                ]
            )
        tables = {
            "source_records": sources,
            "vehicle_context_records": vehicles,
            "region_records": regions,
            "contextual_operation_records": operations,
            "contextual_coverage_matrix": coverage,
            "refresh_recalculation_records": refreshes,
            "review_records": reviews,
        }
        files = []
        for role, rows in tables.items():
            filename = f"{role}.csv"
            self.write_csv(package / filename, rows)
            content = (package / filename).read_bytes()
            files.append(
                {
                    "role": role,
                    "path": filename,
                    "bytes": len(content),
                    "sha256": hashlib.sha256(content).hexdigest(),
                }
            )
        manifest = {
            "schema_version": 1,
            "package_version": "2026q2-v1",
            "frozen_at": "2026-07-02T12:00:00Z",
            "hash_algorithm": "sha256",
            "manifest_serialization": "exact_utf8_bytes",
            "access_controlled_location": "acl://contextual-pricing/2026q2-v1",
            "coverage_contract_version": "1",
            "countries": {"US": "USD", "CA": "CAD"},
            "files": files,
        }
        (package / "contextual_pricing_manifest.json").write_text(
            json.dumps(manifest), encoding="utf-8"
        )
        return package

    def read_csv(self, path: Path) -> list[dict[str, str]]:
        with path.open(newline="", encoding="utf-8") as handle:
            return list(csv.DictReader(handle))

    def refresh_manifest(self, package: Path, filename: str) -> None:
        manifest_path = package / "contextual_pricing_manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        content = (package / filename).read_bytes()
        for record in manifest["files"]:
            if record["path"] == filename:
                record["bytes"] = len(content)
                record["sha256"] = hashlib.sha256(content).hexdigest()
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

    def test_repository_contract_has_exact_two_country_contextual_matrix(self) -> None:
        result = subprocess.run(
            [
                sys.executable,
                str(VALIDATOR),
                "--repository-root",
                str(REPOSITORY_ROOT),
            ],
            cwd=REPOSITORY_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn("28 unsupported contextual coverage rows", result.stdout)
        self.assertIn("8 excluded candidate routes", result.stdout)

    def test_valid_scoped_contextual_package_passes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_package_validator(
                self.create_package(Path(directory))
            )

        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn("PASS", result.stdout)

    def test_country_currency_and_source_dates_must_reconcile(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = self.create_package(Path(directory))
            path = package / "source_records.csv"
            rows = self.read_csv(path)
            rows[1]["currency"] = "USD"
            rows[1]["effective_end"] = "2026-03-31"
            rows[1]["expires_at"] = "2026-05-01"
            self.write_csv(path, rows)
            self.refresh_manifest(package, path.name)
            result = self.run_package_validator(package)

        self.assertNotEqual(0, result.returncode)
        self.assertIn("country/currency mismatch", result.stdout)
        self.assertIn("source chronology is inconsistent", result.stdout)

    def test_vin_prefill_cannot_imply_manual_context_fitment_or_market(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = self.create_package(Path(directory))
            path = package / "vehicle_context_records.csv"
            rows = self.read_csv(path)
            rows[0]["context_method"] = "vin_prefill_unconfirmed"
            rows[0]["vin_prefill_source_id"] = "src-shop-us"
            rows[0]["vin_prefill_status"] = "decoded"
            rows[0]["manual_confirmation_status"] = "confirmed"
            rows[0]["equipment_status"] = "confirmed"
            rows[0]["exact_fitment_status"] = "confirmed_separately"
            rows[0]["market_availability_status"] = "confirmed_separately"
            self.write_csv(path, rows)
            self.refresh_manifest(package, path.name)
            result = self.run_package_validator(package)

        self.assertNotEqual(0, result.returncode)
        self.assertIn("unconfirmed VIN prefill cannot imply manual confirmation", result.stdout)
        self.assertIn("VIN decoding cannot establish equipment, fitment, or market availability", result.stdout)

    def test_region_rate_bases_remain_distinct(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = self.create_package(Path(directory))
            path = package / "region_records.csv"
            rows = self.read_csv(path)
            rows[0]["rate_basis"] = "regional_default"
            rows[0]["repair_shop_rate_status"] = "verified"
            rows[0]["regional_default_status"] = "not_used"
            rows[0]["insurer_program_schedule_status"] = "verified"
            rows[0]["employee_wage_status"] = "verified"
            self.write_csv(path, rows)
            self.refresh_manifest(package, path.name)
            result = self.run_package_validator(package)

        self.assertNotEqual(0, result.returncode)
        self.assertIn("rate basis status is inconsistent", result.stdout)
        self.assertIn("employee wages cannot be treated as customer billing rates", result.stdout)
        self.assertIn("program schedule cannot create retail regional coverage", result.stdout)

    def test_missing_stale_or_cross_context_pricing_never_becomes_zero(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = self.create_package(Path(directory))
            path = package / "contextual_operation_records.csv"
            rows = self.read_csv(path)
            rows[1]["pricing_status"] = "unavailable"
            rows[1]["minimum_amount_minor"] = "0"
            rows[1]["maximum_amount_minor"] = "0"
            rows[1]["vehicle_context_id"] = "vehicle-context-us"
            rows[1]["quote_observed_at"] = "2027-01-01"
            self.write_csv(path, rows)
            self.refresh_manifest(package, path.name)
            result = self.run_package_validator(package)

        self.assertNotEqual(0, result.returncode)
        self.assertIn("unavailable pricing must not contain amounts", result.stdout)
        self.assertIn("vehicle context country mismatch", result.stdout)
        self.assertIn("expired or stale pricing must remain unavailable", result.stdout)

    def test_currency_conversion_never_creates_regional_coverage(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = self.create_package(Path(directory))
            path = package / "contextual_operation_records.csv"
            rows = self.read_csv(path)
            rows[1]["evidence_type"] = "currency_conversion"
            rows[1]["pricing_status"] = "verified"
            self.write_csv(path, rows)
            self.refresh_manifest(package, path.name)
            result = self.run_package_validator(package)

        self.assertNotEqual(0, result.returncode)
        self.assertIn("currency conversion cannot create regional coverage", result.stdout)

    def test_source_evidence_invoice_and_supplement_states_stay_distinct(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = self.create_package(Path(directory))
            path = package / "contextual_operation_records.csv"
            rows = self.read_csv(path)
            rows[0]["evidence_type"] = "repair_shop_estimate"
            rows[0]["estimate_invoice_status"] = "estimate"
            rows[0]["supplement_status"] = "pending"
            self.write_csv(path, rows)
            self.refresh_manifest(package, path.name)
            result = self.run_package_validator(package)

        self.assertNotEqual(0, result.returncode)
        self.assertIn("evidence_type is inconsistent with source", result.stdout)
        self.assertIn("estimate/invoice status is inconsistent with source", result.stdout)
        self.assertIn("supplement status is inconsistent with source", result.stdout)

    def test_duplicate_conflicts_and_shared_operations_fail(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = self.create_package(Path(directory))
            path = package / "contextual_operation_records.csv"
            rows = self.read_csv(path)
            duplicate = dict(rows[0])
            duplicate["pricing_record_id"] = "pricing-us-duplicate"
            duplicate["maximum_amount_minor"] = "70000"
            self.write_csv(path, rows + [duplicate])
            self.refresh_manifest(package, path.name)
            result = self.run_package_validator(package)

        self.assertNotEqual(0, result.returncode)
        self.assertIn("conflicting contextual pricing records", result.stdout)
        self.assertIn("shared operation group counted more than once", result.stdout)

    def test_supported_coverage_reconciles_every_contextual_dimension(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = self.create_package(Path(directory))
            path = package / "contextual_coverage_matrix.csv"
            rows = self.read_csv(path)
            rows[0]["labor_category"] = "body"
            rows[0]["parts_provenance"] = "aftermarket"
            rows[0]["effective_or_observation_date"] = "2026-06-14"
            self.write_csv(path, rows)
            self.refresh_manifest(package, path.name)
            result = self.run_package_validator(package)

        self.assertNotEqual(0, result.returncode)
        self.assertIn("supported coverage does not reconcile all contextual dimensions", result.stdout)

    def test_refresh_preserves_completed_revisions_and_forbids_conversion(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = self.create_package(Path(directory))
            path = package / "refresh_recalculation_records.csv"
            rows = self.read_csv(path)
            rows[1]["draft_recalculation_status"] = "automatic"
            rows[1]["completed_revision_status"] = "rewritten"
            rows[1]["currency_conversion_used"] = "true"
            self.write_csv(path, rows)
            self.refresh_manifest(package, path.name)
            result = self.run_package_validator(package)

        self.assertNotEqual(0, result.returncode)
        self.assertIn("draft recalculation must be explicit", result.stdout)
        self.assertIn("completed revisions must remain frozen", result.stdout)
        self.assertIn("currency conversion cannot create or refresh coverage", result.stdout)

    def test_appraiser_acceptance_requires_qualification(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = self.create_package(Path(directory))
            path = package / "review_records.csv"
            rows = self.read_csv(path)
            rows[0]["reviewer_qualification_status"] = "unavailable"
            self.write_csv(path, rows)
            self.refresh_manifest(package, path.name)
            result = self.run_package_validator(package)

        self.assertNotEqual(0, result.returncode)
        self.assertIn("accepted Appraiser review requires verified qualification", result.stdout)

    def test_completion_deliberately_fails_for_real_evidence_blockers(self) -> None:
        result = subprocess.run(
            [
                sys.executable,
                str(VALIDATOR),
                "--repository-root",
                str(REPOSITORY_ROOT),
                "--require-complete",
            ],
            cwd=REPOSITORY_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertNotEqual(0, result.returncode)
        self.assertIn("authorized_usd_and_cad_access", result.stdout)
        self.assertIn("independent_appraiser_qualification", result.stdout)
        self.assertIn("human_release_gate_evidence", result.stdout)

    def test_package_completion_requires_contextual_coverage_for_both_countries(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = self.create_package(Path(directory))
            result = self.run_package_validator(package, "--require-complete")

        self.assertNotEqual(0, result.returncode)
        self.assertIn("complete package requires all 14 supported classes in US/USD", result.stdout)
        self.assertIn("complete package requires all 14 supported classes in CA/CAD", result.stdout)

    def test_controlled_values_are_enforced_across_package_records(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = self.create_package(Path(directory))
            operation_path = package / "contextual_operation_records.csv"
            operation_rows = self.read_csv(operation_path)
            operation_rows[0]["labor_category"] = "general_labor"
            operation_rows[0]["parts_provenance"] = "cheap_part"
            self.write_csv(operation_path, operation_rows)
            self.refresh_manifest(package, operation_path.name)
            refresh_path = package / "refresh_recalculation_records.csv"
            refresh_rows = self.read_csv(refresh_path)
            refresh_rows[0]["refresh_outcome"] = "probably_current"
            self.write_csv(refresh_path, refresh_rows)
            self.refresh_manifest(package, refresh_path.name)
            result = self.run_package_validator(package)

        self.assertNotEqual(0, result.returncode)
        self.assertIn("invalid labor category", result.stdout)
        self.assertIn("invalid parts provenance", result.stdout)
        self.assertIn("invalid refresh outcome", result.stdout)


if __name__ == "__main__":
    unittest.main()
