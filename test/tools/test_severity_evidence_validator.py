import csv
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from tool.severity_evidence_validator import validate_evidence_package


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
VALIDATOR = REPOSITORY_ROOT / "tool/severity_evidence_validator.py"


class SeverityEvidenceValidatorCliTest(unittest.TestCase):
    def test_repository_contract_passes_with_explicit_unavailable_evidence(self):
        result = subprocess.run(
            [
                sys.executable,
                str(VALIDATOR),
                "--repository-root",
                str(REPOSITORY_ROOT),
            ],
            check=False,
            capture_output=True,
            text=True,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PASS: severity evidence repository contract", result.stdout)
        self.assertIn("unavailable completion gates", result.stdout)


class SeverityEvidencePackageTest(unittest.TestCase):
    def setUp(self):
        self._temporary_directory = tempfile.TemporaryDirectory()
        self.package = Path(self._temporary_directory.name)
        self._write_synthetic_package()

    def tearDown(self):
        self._temporary_directory.cleanup()

    def test_accepts_a_structurally_valid_synthetic_package(self):
        self.assertEqual(validate_evidence_package(self.package, REPOSITORY_ROOT), [])

    def test_rejects_cross_partition_incident_leakage(self):
        self._write_rows(
            "partitions",
            [
                {
                    "finding_id": "finding-train",
                    "vehicle_group_id": "vehicle-train",
                    "incident_group_id": "incident-shared",
                    "assessment_group_id": "assessment-train",
                    "session_group_id": "session-train",
                    "original_asset_id": "original-train",
                    "near_duplicate_group_id": "near-train",
                    "adjacent_frame_group_id": "frame-train",
                    "partition": "train",
                    "allocation_group_id": "allocation-train",
                    "allocation_method_version": "synthetic-1",
                    "allocated_at": "2026-09-09T16:00:00Z",
                    "sealed_at": "2026-09-09T17:00:00Z",
                    "notes": "Synthetic workflow evidence only.",
                },
                {
                    "finding_id": "finding-final",
                    "vehicle_group_id": "vehicle-final",
                    "incident_group_id": "incident-shared",
                    "assessment_group_id": "assessment-final",
                    "session_group_id": "session-final",
                    "original_asset_id": "original-final",
                    "near_duplicate_group_id": "near-final",
                    "adjacent_frame_group_id": "frame-final",
                    "partition": "final_test",
                    "allocation_group_id": "allocation-final",
                    "allocation_method_version": "synthetic-1",
                    "allocated_at": "2026-09-09T16:00:00Z",
                    "sealed_at": "2026-09-09T17:00:00Z",
                    "notes": "Synthetic workflow evidence only.",
                },
            ],
        )

        errors = validate_evidence_package(self.package, REPOSITORY_ROOT)

        self.assertTrue(any("incident_group_id" in error for error in errors))

    def test_completion_rejects_synthetic_reviewers_and_annotations(self):
        self._write_rows(
            "reviewers",
            [
                {
                    "reviewer_id": "synthetic-a",
                    "reviewer_role": "qualified_appraiser_a",
                    "synthetic_persona": "true",
                    "qualification_status": "synthetic_only",
                    "qualification_type": "simulated workflow persona",
                    "qualification_evidence_uri": "",
                    "qualification_evidence_sha256": "",
                    "verified_by": "",
                    "verified_at": "",
                    "conflict_of_interest": "not_applicable",
                    "notes": "Synthetic workflow evidence only.",
                },
                {
                    "reviewer_id": "synthetic-b",
                    "reviewer_role": "qualified_appraiser_b",
                    "synthetic_persona": "true",
                    "qualification_status": "synthetic_only",
                    "qualification_type": "simulated workflow persona",
                    "qualification_evidence_uri": "",
                    "qualification_evidence_sha256": "",
                    "verified_by": "",
                    "verified_at": "",
                    "conflict_of_interest": "not_applicable",
                    "notes": "Synthetic workflow evidence only.",
                },
            ],
        )
        self._write_rows(
            "annotations",
            [
                {
                    "annotation_id": "synthetic-label-a",
                    "example_id": "synthetic-example",
                    "finding_id": "synthetic-finding",
                    "review_round": "1",
                    "assignment_role": "original_reviewer_a",
                    "reviewer_id": "synthetic-a",
                    "independent_and_blinded": "true",
                    "rubric_version": "synthetic-1",
                    "severity_label": "Minor",
                    "visible_extent_reason": "Localized synthetic fixture.",
                    "uncertainty_reason": "",
                    "additional_view_request": "",
                    "conflicting_views": "false",
                    "labelled_at": "2026-09-09T16:00:00Z",
                    "synthetic": "true",
                    "notes": "Synthetic workflow evidence only.",
                }
            ],
        )

        errors = validate_evidence_package(
            self.package,
            REPOSITORY_ROOT,
            require_complete=True,
        )

        self.assertTrue(any("synthetic reviewer" in error for error in errors))
        self.assertTrue(any("synthetic annotation" in error for error in errors))

    def test_rejects_bad_ordinal_distance_and_non_lead_adjudication(self):
        self._write_rows(
            "reviewers",
            [
                self._reviewer("appraiser-a", "qualified_appraiser_a"),
                self._reviewer("appraiser-b", "qualified_appraiser_b"),
                self._reviewer("lead", "adjudication_lead"),
            ],
        )
        self._write_rows(
            "annotations",
            [
                self._annotation("annotation-a", "appraiser-a", "Minor", "original_reviewer_a"),
                self._annotation("annotation-b", "appraiser-b", "Severe", "original_reviewer_b"),
            ],
        )
        self._write_rows(
            "disagreements",
            [
                {
                    "disagreement_id": "disagreement-1",
                    "finding_id": "finding-1",
                    "rubric_version": "rubric-1",
                    "annotation_a_id": "annotation-a",
                    "annotation_b_id": "annotation-b",
                    "label_a": "Minor",
                    "label_b": "Severe",
                    "ordinal_distance": "1",
                    "disagreement_codes": "severity_label",
                    "status": "adjudicated",
                    "created_at": "2026-09-09T16:30:00Z",
                    "notes": "Synthetic fixture with intentionally wrong distance.",
                }
            ],
        )
        self._write_rows(
            "adjudications",
            [
                {
                    "adjudication_id": "adjudication-1",
                    "disagreement_id": "disagreement-1",
                    "finding_id": "finding-1",
                    "lead_reviewer_id": "appraiser-a",
                    "rubric_version": "rubric-1",
                    "accepted_severity_label": "Moderate",
                    "rationale": "Synthetic workflow exercise.",
                    "decided_at": "2026-09-09T17:00:00Z",
                    "synthetic": "true",
                    "notes": "Synthetic workflow evidence only.",
                }
            ],
        )

        errors = validate_evidence_package(self.package, REPOSITORY_ROOT)

        self.assertTrue(any("ordinal_distance" in error for error in errors))
        self.assertTrue(any("designated adjudication lead" in error for error in errors))

    def test_rejects_example_without_verified_item_level_rights(self):
        self._write_rows(
            "examples",
            [
                {
                    "example_id": "example-1",
                    "finding_id": "finding-1",
                    "capture_id": "capture-1",
                    "source_id": "candidate-source",
                    "vehicle_group_id": "vehicle-1",
                    "incident_group_id": "incident-1",
                    "assessment_group_id": "assessment-1",
                    "physical_defect_id": "defect-1",
                    "component_family": "outer_door",
                    "component_position": "left_front",
                    "damage_type": "dent",
                    "visibility": "fully_visible",
                    "conflicting_views": "false",
                    "rights_record_id": "rights-dataset-only",
                    "content_sha256": "b" * 64,
                    "bytes": "100",
                    "media_type": "image/jpeg",
                    "capture_time": "2026-09-09T14:00:00Z",
                    "synthetic": "true",
                    "notes": "Synthetic fixture only.",
                }
            ],
        )
        self._write_rows(
            "rights_records",
            [
                {
                    "rights_record_id": "rights-dataset-only",
                    "source_id": "candidate-source",
                    "example_id": "",
                    "evidence_scope": "dataset",
                    "rightsholder_or_licensor": "synthetic-owner",
                    "evaluation_permission": "unverified",
                    "training_permission": "unverified",
                    "storage_permission": "unverified",
                    "derived_model_permission": "unverified",
                    "publication_permission": "unverified",
                    "redistribution_permission": "unverified",
                    "privacy_publicity_review": "unverified",
                    "required_attribution": "",
                    "evidence_uri": "access-controlled://synthetic/rights",
                    "evidence_sha256": "c" * 64,
                    "verified_by": "synthetic-verifier",
                    "verified_at": "2026-09-09T14:30:00Z",
                    "unresolved_constraints": "Item-level rights are absent.",
                    "synthetic": "true",
                }
            ],
        )

        errors = validate_evidence_package(self.package, REPOSITORY_ROOT)

        self.assertTrue(any("verified item-level rights" in error for error in errors))

    def test_rejects_final_test_opened_before_selection_freeze(self):
        manifest_path = self.package / "severity_evidence_manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest["selection_frozen_at"] = "2026-09-09T18:00:00Z"
        manifest["final_test_opened_at"] = "2026-09-09T17:00:00Z"
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

        errors = validate_evidence_package(self.package, REPOSITORY_ROOT)

        self.assertTrue(any("final test was opened before selection freeze" in error for error in errors))

    def _write_synthetic_package(self):
        contract = json.loads(
            (
                REPOSITORY_ROOT
                / "docs/research/severity_evaluation/contract.json"
            ).read_text(encoding="utf-8")
        )
        files = []
        for role, filename in contract["package_files"].items():
            path = self.package / filename
            with path.open("w", encoding="utf-8", newline="") as handle:
                writer = csv.DictWriter(
                    handle,
                    fieldnames=contract["package_columns"][role],
                    lineterminator="\n",
                )
                writer.writeheader()
            files.append(
                {
                    "role": role,
                    "path": filename,
                    "bytes": path.stat().st_size,
                    "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                }
            )
        manifest = {
            "schema_version": 1,
            "package_version": "synthetic-structure-1",
            "frozen_at": "2026-09-09T18:00:00Z",
            "hash_algorithm": "sha256",
            "manifest_serialization": "exact_utf8_bytes",
            "access_controlled_location": "access-controlled://synthetic-test",
            "rubric_version": "synthetic-1",
            "corpus_identity": "synthetic-empty-structure",
            "selection_frozen_at": "2026-09-09T17:00:00Z",
            "final_test_opened_at": None,
            "files": files,
        }
        (self.package / "severity_evidence_manifest.json").write_text(
            json.dumps(manifest, indent=2) + "\n",
            encoding="utf-8",
        )

    def _write_rows(self, role, rows):
        contract = json.loads(
            (
                REPOSITORY_ROOT
                / "docs/research/severity_evaluation/contract.json"
            ).read_text(encoding="utf-8")
        )
        filename = contract["package_files"][role]
        path = self.package / filename
        with path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(
                handle,
                fieldnames=contract["package_columns"][role],
                lineterminator="\n",
            )
            writer.writeheader()
            writer.writerows(rows)
        manifest_path = self.package / "severity_evidence_manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        record = next(item for item in manifest["files"] if item["role"] == role)
        record["bytes"] = path.stat().st_size
        record["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    @staticmethod
    def _reviewer(reviewer_id, role):
        return {
            "reviewer_id": reviewer_id,
            "reviewer_role": role,
            "synthetic_persona": "false",
            "qualification_status": "verified",
            "qualification_type": "synthetic fixture qualification",
            "qualification_evidence_uri": "access-controlled://synthetic/qualification",
            "qualification_evidence_sha256": "a" * 64,
            "verified_by": "synthetic-verifier",
            "verified_at": "2026-09-09T15:00:00Z",
            "conflict_of_interest": "none_declared",
            "notes": "Synthetic fixture only; not real qualification evidence.",
        }

    @staticmethod
    def _annotation(annotation_id, reviewer_id, label, assignment_role):
        return {
            "annotation_id": annotation_id,
            "example_id": "example-1",
            "finding_id": "finding-1",
            "review_round": "1",
            "assignment_role": assignment_role,
            "reviewer_id": reviewer_id,
            "independent_and_blinded": "true",
            "rubric_version": "rubric-1",
            "severity_label": label,
            "visible_extent_reason": "Synthetic visible-extent rationale.",
            "uncertainty_reason": "",
            "additional_view_request": "",
            "conflicting_views": "false",
            "labelled_at": "2026-09-09T16:00:00Z",
            "synthetic": "true",
            "notes": "Synthetic workflow evidence only.",
        }


if __name__ == "__main__":
    unittest.main()
