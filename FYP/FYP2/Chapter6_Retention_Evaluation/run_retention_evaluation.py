import datetime as datetime_module
import importlib.util
import json
import math
from pathlib import Path


FIXED_NOW = datetime_module.datetime(2026, 9, 9, 12, 0, 0)
TOLERANCE = 0.01
PRODUCTION_FILE = Path(__file__).resolve().parents[2] / "backend" / "utils" / "mastery_engine.py"
EVIDENCE_FILE = Path(__file__).with_name("retention_formula_verification.json")


TEST_CASES = [
    {
        "id": "RET-01",
        "scenario": "Very recent review / high retention",
        "last_percentage": 96,
        "last_reviewed_at": "2026-09-09 06:00:00",
        "review_count": 1,
    },
    {
        "id": "RET-02",
        "scenario": "Moderate decay with repeated-review stability",
        "last_percentage": 92,
        "last_reviewed_at": "2026-09-05 12:00:00",
        "review_count": 3,
    },
    {
        "id": "RET-03",
        "scenario": "Near the high-to-medium threshold",
        "last_percentage": 100,
        "last_reviewed_at": "2026-09-07 22:48:00",
        "review_count": 1,
    },
    {
        "id": "RET-04",
        "scenario": "Near and below the review-needed threshold",
        "last_percentage": 100,
        "last_reviewed_at": "2026-09-07 20:24:00",
        "review_count": 1,
    },
    {
        "id": "RET-05",
        "scenario": "Later review / low retention",
        "last_percentage": 90,
        "last_reviewed_at": "2026-08-26 12:00:00",
        "review_count": 1,
    },
]


def load_production_module():
    spec = importlib.util.spec_from_file_location("production_mastery_engine", PRODUCTION_FILE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def expected_category(score):
    if score >= 80:
        return "fresh", "Fresh (Mastered)", False
    if score >= 50:
        return "fading", "Fading (Review Soon)", True
    return "critical", "At Risk (Review Needed)", True


def calculate_expected(case):
    reviewed_at = datetime_module.datetime.strptime(case["last_reviewed_at"], "%Y-%m-%d %H:%M:%S")
    days_elapsed = max(0.0, (FIXED_NOW - reviewed_at).total_seconds() / 86400.0)
    normalized_review_count = max(1, int(case["review_count"] or 1))
    stability = 1.0 + (0.65 * (normalized_review_count - 1))
    decay_factor = math.exp(-days_elapsed / (7.0 * stability))
    raw_retention = max(0.0, min(100.0, float(case["last_percentage"]) * decay_factor))
    mastery_score = round(raw_retention)
    status, status_label, needs_review = expected_category(mastery_score)
    return {
        "days_elapsed": days_elapsed,
        "stability": stability,
        "decay_factor": decay_factor,
        "raw_retention": raw_retention,
        "mastery_score": mastery_score,
        "status": status,
        "status_label": status_label,
        "needs_review": needs_review,
    }


def main():
    production = load_production_module()
    real_datetime_class = production.datetime.datetime

    class FixedDateTime(real_datetime_class):
        @classmethod
        def now(cls, tz=None):
            if tz is not None:
                return tz.fromutc(FIXED_NOW.replace(tzinfo=tz))
            return cls(
                FIXED_NOW.year,
                FIXED_NOW.month,
                FIXED_NOW.day,
                FIXED_NOW.hour,
                FIXED_NOW.minute,
                FIXED_NOW.second,
            )

    results = []
    production.datetime.datetime = FixedDateTime
    try:
        for case in TEST_CASES:
            expected = calculate_expected(case)
            actual = production.calculate_topic_mastery(
                case["last_percentage"],
                case["last_reviewed_at"],
                case["review_count"],
            )
            absolute_difference = abs(float(expected["mastery_score"]) - float(actual["mastery_score"]))
            value_matches = absolute_difference <= TOLERANCE
            category_matches = (
                expected["status"] == actual["status"]
                and expected["status_label"] == actual["status_label"]
                and expected["needs_review"] == actual["needs_review"]
            )
            results.append(
                {
                    **case,
                    "expected": expected,
                    "actual": actual,
                    "expected_retention_value": expected["mastery_score"],
                    "actual_retention_value": actual["mastery_score"],
                    "expected_category": expected["status"],
                    "actual_category": actual["status"],
                    "absolute_difference": absolute_difference,
                    "tolerance": TOLERANCE,
                    "value_matches": value_matches,
                    "category_matches": category_matches,
                    "result": "PASS" if value_matches and category_matches else "FAIL",
                }
            )
    finally:
        production.datetime.datetime = real_datetime_class

    evidence = {
        "production_source_file": str(PRODUCTION_FILE),
        "production_function": "calculate_topic_mastery",
        "fixed_evaluation_time": FIXED_NOW.strftime("%Y-%m-%d %H:%M:%S"),
        "formula": {
            "days_elapsed": "max(0.0, (now - last_reviewed_at).total_seconds() / 86400.0)",
            "stability": "1.0 + (0.65 * (max(1, int(review_count or 1)) - 1))",
            "decay_factor": "exp(-days_elapsed / (7.0 * stability))",
            "raw_retention": "max(0.0, min(100.0, float(last_percentage) * decay_factor))",
            "mastery_score": "round(raw_retention)",
        },
        "constants_and_thresholds": {
            "minimum_review_count": 1,
            "base_stability": 1.0,
            "stability_increment_per_additional_review": 0.65,
            "decay_time_parameter_days": 7.0,
            "seconds_per_day": 86400.0,
            "retention_minimum": 0.0,
            "retention_maximum": 100.0,
            "fresh_threshold_inclusive": 80,
            "fading_threshold_inclusive": 50,
            "critical_threshold": "mastery_score < 50",
        },
        "comparison_tolerance": TOLERANCE,
        "comparison_basis": "The production function returns round(raw_retention), so the independently calculated raw value is rounded before comparison with the returned integer mastery_score.",
        "parameter_classification": {
            "classification": "prototype/design heuristics",
            "parameters": [0.65, 7.0, 80, 50],
            "basis": "The inspected production implementation defines these values directly and contains no citation or calibration evidence that scientifically validates them.",
            "scientifically_validated": False,
        },
        "test_cases": results,
        "summary": {
            "total": len(results),
            "passed": sum(item["result"] == "PASS" for item in results),
            "failed": sum(item["result"] == "FAIL" for item in results),
            "overall_result": "PASS" if all(item["result"] == "PASS" for item in results) else "FAIL",
        },
        "interpretation_limit": "These deterministic checks verify implementation consistency for selected inputs; they do not scientifically validate the heuristic formula, constants, or thresholds.",
    }
    EVIDENCE_FILE.write_text(json.dumps(evidence, indent=2), encoding="utf-8")

    print(f"Production function: {PRODUCTION_FILE}::calculate_topic_mastery")
    print(f"Fixed evaluation time: {evidence['fixed_evaluation_time']}")
    print(f"Tolerance: {TOLERANCE}")
    for item in results:
        print(
            f"{item['id']} | expected={item['expected']['mastery_score']} "
            f"actual={item['actual']['mastery_score']} diff={item['absolute_difference']:.12g} "
            f"expected_status={item['expected']['status']} actual_status={item['actual']['status']} "
            f"result={item['result']}"
        )
    print(f"Summary: {evidence['summary']['passed']}/{evidence['summary']['total']} PASS")
    print(f"Evidence: {EVIDENCE_FILE}")


if __name__ == "__main__":
    main()
