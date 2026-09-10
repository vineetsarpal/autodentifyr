import csv
import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tool.phase_one_corpus_validator import (
    validate_corpus_package,
    validate_repository_contract,
)


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]


class RepositoryContractTest(unittest.TestCase):
    def test_repository_contract_is_internally_consistent(self):
        self.assertEqual(validate_repository_contract(REPOSITORY_ROOT), [])


class CorpusPackageValidationTest(unittest.TestCase):
    def setUp(self):
        self._temp_directory = tempfile.TemporaryDirectory()
        self.package = Path(self._temp_directory.name)
        self._write_valid_package()

    def tearDown(self):
        self._temp_directory.cleanup()

    def test_accepts_a_consistent_synthetic_package(self):
        self.assertEqual(validate_corpus_package(self.package), [])

    def test_rejects_a_checksum_mismatch(self):
        with (self.package / "images.csv").open("a", encoding="utf-8") as handle:
            handle.write("\n")

        errors = validate_corpus_package(self.package)

        self.assertTrue(any("checksum mismatch" in error for error in errors))

    def test_rejects_a_missing_required_column(self):
        rows = self._read_csv("images.csv")
        for row in rows:
            row.pop("session_id")
        self._write_csv("images.csv", rows)
        self._refresh_manifest_hashes()

        errors = validate_corpus_package(self.package)

        self.assertTrue(any("images.csv columns" in error for error in errors))

    def test_rejects_vehicle_and_session_split_leakage(self):
        rows = self._read_csv("images.csv")
        rows[1]["vehicle_id"] = rows[0]["vehicle_id"]
        rows[2]["session_id"] = rows[0]["session_id"]
        self._write_csv("images.csv", rows)
        self._refresh_manifest_hashes()

        errors = validate_corpus_package(self.package)

        self.assertTrue(any("vehicle_id" in error for error in errors))
        self.assertTrue(any("session_id" in error for error in errors))

    def test_rejects_original_near_duplicate_and_adjacent_frame_leakage(self):
        rows = self._read_csv("images.csv")
        rows[1]["original_sha256"] = rows[0]["original_sha256"]
        rows[1]["near_duplicate_group_id"] = rows[0]["near_duplicate_group_id"]
        rows[2]["adjacent_frame_group_id"] = rows[0]["adjacent_frame_group_id"]
        self._write_csv("images.csv", rows)
        self._refresh_manifest_hashes()

        errors = validate_corpus_package(self.package)

        self.assertTrue(any("original_sha256" in error for error in errors))
        self.assertTrue(any("near_duplicate_group_id" in error for error in errors))
        self.assertTrue(any("adjacent_frame_group_id" in error for error in errors))

    def test_rejects_hidden_or_uninspected_surface_as_negative(self):
        rows = self._read_csv("annotations.csv")
        rows[0]["annotation_outcome"] = "negative"
        rows[0]["visibility"] = "not_visible"
        rows[0]["inspection_scope"] = "uninspected"
        self._write_csv("annotations.csv", rows)
        self._refresh_manifest_hashes()

        errors = validate_corpus_package(self.package)

        self.assertTrue(any("must not be recorded as negative" in error for error in errors))

    def test_rejects_position_inferred_from_a_generic_raw_class(self):
        rows = self._read_csv("annotations.csv")
        rows[0]["raw_class"] = "doorouter-dent"
        rows[0]["component_position"] = "left_front"
        rows[0]["component_position_source"] = "raw_class"
        self._write_csv("annotations.csv", rows)
        self._refresh_manifest_hashes()

        errors = validate_corpus_package(self.package)

        self.assertTrue(any("position" in error and "raw class" in error for error in errors))

    def test_rejects_dataset_level_permission_as_per_image_permission(self):
        rows = self._read_csv("source_permissions.csv")
        rows[1]["evidence_scope"] = "dataset"
        rows[1]["item_id"] = ""
        self._write_csv("source_permissions.csv", rows)
        self._refresh_manifest_hashes()

        errors = validate_corpus_package(self.package)

        self.assertTrue(any("per-image rights" in error for error in errors))

    def test_rejects_final_test_opening_before_selection_freeze(self):
        manifest = json.loads((self.package / "corpus_manifest.json").read_text())
        manifest["selection_frozen_at"] = "2026-09-08T13:00:00Z"
        manifest["final_test_opened_at"] = "2026-09-08T12:00:00Z"
        self._write_manifest(manifest)

        errors = validate_corpus_package(self.package)

        self.assertTrue(any("final test was opened before" in error for error in errors))

    def test_rejects_a_count_that_disagrees_with_source_records(self):
        rows = self._read_csv("counts.csv")
        rows[0]["count"] = "99"
        self._write_csv("counts.csv", rows)
        self._refresh_manifest_hashes()

        errors = validate_corpus_package(self.package)

        self.assertTrue(any("count mismatch" in error for error in errors))

    def test_rejects_inconsistent_physical_defect_identity_across_views(self):
        rows = self._read_csv("annotations.csv")
        second = dict(rows[0])
        second["annotation_id"] = "annotation-2"
        second["item_id"] = "image-calibration"
        second["component_family"] = "fender"
        rows.append(second)
        self._write_csv("annotations.csv", rows)
        self._refresh_manifest_hashes()

        errors = validate_corpus_package(self.package)

        self.assertTrue(any("physical_defect_id" in error for error in errors))

    def test_completion_gate_rejects_protocol_only_fixture(self):
        errors = validate_corpus_package(self.package, require_complete=True)

        self.assertTrue(any("corpus_manifest.sha256" in error for error in errors))
        self.assertTrue(any("populated count strata" in error for error in errors))
        self.assertTrue(any("final-test opening" in error for error in errors))

    def _write_valid_package(self):
        contract = json.loads(
            (
                REPOSITORY_ROOT
                / "docs/research/phase_one_evaluation_corpus/contract.json"
            ).read_text()
        )
        with (
            REPOSITORY_ROOT
            / "docs/research/phase_one_evaluation_corpus/class_mapping.csv"
        ).open(encoding="utf-8", newline="") as handle:
            mapping_rows = list(csv.DictReader(handle))
        self._write_csv("class_mapping.csv", mapping_rows)
        self._write_csv(
            "images.csv",
            [
                self._image("image-train", "vehicle-train", "session-train", "train", "a"),
                self._image(
                    "image-calibration",
                    "vehicle-calibration",
                    "session-calibration",
                    "calibration",
                    "b",
                ),
                self._image(
                    "image-final",
                    "vehicle-final",
                    "session-final",
                    "final_test",
                    "c",
                ),
            ],
        )
        self._write_csv(
            "source_permissions.csv",
            [
                {
                    "permission_record_id": "permission-dataset",
                    "source_id": "shop-capture",
                    "evidence_scope": "dataset",
                    "item_id": "",
                    "claim_type": "storage_and_evaluation",
                    "claim_status": "verified",
                    "evidence_uri": "access-controlled://permission/dataset",
                    "evidence_sha256": "d" * 64,
                    "verified_by": "rights-reviewer",
                    "verified_at": "2026-09-08T10:00:00Z",
                    "unresolved_constraints": "",
                },
                *[
                    {
                        "permission_record_id": f"permission-{item}",
                        "source_id": "shop-capture",
                        "evidence_scope": "item",
                        "item_id": item,
                        "claim_type": "storage_and_evaluation",
                        "claim_status": "verified",
                        "evidence_uri": f"access-controlled://permission/{item}",
                        "evidence_sha256": "e" * 64,
                        "verified_by": "rights-reviewer",
                        "verified_at": "2026-09-08T10:00:00Z",
                        "unresolved_constraints": "",
                    }
                    for item in ("image-train", "image-calibration", "image-final")
                ],
            ],
        )
        self._write_csv(
            "annotations.csv",
            [
                {
                    "annotation_id": "annotation-1",
                    "item_id": "image-train",
                    "physical_defect_id": "defect-1",
                    "annotation_outcome": "positive",
                    "raw_class": "doorouter-dent",
                    "canonical_damage_type": "dent",
                    "component_family": "outer_door",
                    "component_position": "left_front",
                    "component_position_source": "appraiser_adjudication",
                    "visibility": "fully_visible",
                    "inspection_scope": "inspected",
                    "ambiguity": "none",
                    "region_format": "xywh_normalized",
                    "region": "0.1 0.1 0.2 0.2",
                    "unsupported_damage_type": "",
                    "notes": "",
                }
            ],
        )
        self._write_csv(
            "adjudications.csv",
            [
                {
                    "adjudication_id": "adjudication-1",
                    "annotation_id": "annotation-1",
                    "review_round": "1",
                    "reviewer_role": "Appraiser",
                    "reviewer_pseudonymous_id": "appraiser-1",
                    "decision": "accepted",
                    "decided_at": "2026-09-08T11:00:00Z",
                    "disagreement_codes": "",
                    "rationale": "Visible dent and position confirmed.",
                    "guideline_version": "1",
                }
            ],
        )
        self._write_csv(
            "counts.csv",
            [
                {
                    "stratum_type": "split",
                    "stratum_value": split,
                    "split": split,
                    "annotation_outcome": "all",
                    "count_unit": "images",
                    "count": "1",
                }
                for split in ("train", "calibration", "final_test")
            ],
        )
        self._write_csv(
            "leakage_audit.csv",
            [
                {
                    "audit_record_id": "audit-1",
                    "audit_type": "group_and_duplicate_split",
                    "left_item_id": "",
                    "right_item_id": "",
                    "group_or_hash": "all",
                    "finding": "no_cross_split_leakage",
                    "resolution": "not_applicable",
                    "audited_by": "corpus-curator",
                    "audited_at": "2026-09-08T11:30:00Z",
                    "tool_version": "synthetic-test-1",
                    "notes": "Synthetic fixture only.",
                }
            ],
        )
        files = []
        for role, filename in contract["required_files"].items():
            if role == "manifest":
                continue
            path = self.package / filename
            files.append(
                {
                    "role": role,
                    "path": filename,
                    "bytes": path.stat().st_size,
                    "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                }
            )
        self._write_manifest(
            {
                "schema_version": 1,
                "corpus_version": "synthetic-test-1",
                "frozen_at": "2026-09-08T12:00:00Z",
                "hash_algorithm": "sha256",
                "manifest_serialization": "exact_utf8_bytes",
                "access_controlled_location": "access-controlled://synthetic-test",
                "annotation_guideline_version": "1",
                "class_mapping_version": "1",
                "model_artifact_sha256": "f" * 64,
                "preprocessing_version": "synthetic-1",
                "evaluator_version": "synthetic-1",
                "operating_point_version": "synthetic-1",
                "calibration_record_sha256": "1" * 64,
                "selection_frozen_at": "2026-09-08T12:00:00Z",
                "final_test_opened_at": None,
                "final_test_use": "confirmation_only",
                "final_test_tuning_prohibited": True,
                "historical_training_manifest_reconciliation": "unavailable_per_ATD-19",
                "files": files,
            }
        )

    @staticmethod
    def _image(item_id, vehicle_id, session_id, split, marker):
        return {
            "item_id": item_id,
            "source_id": "shop-capture",
            "vehicle_id": vehicle_id,
            "assessment_id": f"assessment-{marker}",
            "session_id": session_id,
            "split": split,
            "original_asset_id": f"original-{marker}",
            "original_sha256": marker * 64,
            "canonical_sha256": marker * 64,
            "bytes": "100",
            "media_type": "image/jpeg",
            "near_duplicate_group_id": f"near-{marker}",
            "adjacent_frame_group_id": f"frame-{marker}",
            "vehicle_damage_status": "damaged" if marker == "a" else "undamaged",
            "supported_vehicle_type": "passenger_car",
            "conditions": "clear",
            "captured_at": "2026-09-08T09:00:00Z",
        }

    def _write_csv(self, filename, rows):
        columns = list(rows[0].keys())
        with (self.package / filename).open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=columns, lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)

    def _read_csv(self, filename):
        with (self.package / filename).open(encoding="utf-8", newline="") as handle:
            return list(csv.DictReader(handle))

    def _write_manifest(self, manifest):
        (self.package / "corpus_manifest.json").write_text(
            json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
        )

    def _refresh_manifest_hashes(self):
        manifest = json.loads((self.package / "corpus_manifest.json").read_text())
        for record in manifest["files"]:
            path = self.package / record["path"]
            record["bytes"] = path.stat().st_size
            record["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        self._write_manifest(manifest)


if __name__ == "__main__":
    unittest.main()
