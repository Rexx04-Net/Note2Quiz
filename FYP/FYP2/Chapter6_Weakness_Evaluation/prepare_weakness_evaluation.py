import json
import urllib.request
import uuid
from pathlib import Path


BASE_URL = "http://127.0.0.1:5000"
OUTPUT_DIR = Path(__file__).resolve().parent
EVIDENCE_FILE = OUTPUT_DIR / "weakness_selection_evidence.json"
MANUAL_REQUEST_FILE = OUTPUT_DIR / "manual_generate_weakness_drill_request.json"


CONTROLLED_MISTAKES = [
    {
        "id": "Q1",
        "question": "Which data structure follows last-in-first-out ordering?",
        "selected_answer": "Queue",
        "correct_answer": "Stack",
        "explanation": "A stack removes the most recently added item first.",
    },
    {
        "id": "Q2",
        "question": "Which data structure follows first-in-first-out ordering?",
        "selected_answer": "Stack",
        "correct_answer": "Queue",
        "explanation": "A queue removes the earliest added item first.",
    },
    {
        "id": "Q3",
        "question": "Which traversal normally uses a queue to explore vertices level by level?",
        "selected_answer": "Depth-first search",
        "correct_answer": "Breadth-first search",
        "explanation": "Breadth-first search uses a queue for level-order exploration.",
    },
    {
        "id": "Q4",
        "question": "Which traversal can use a stack to explore one branch before backtracking?",
        "selected_answer": "Breadth-first search",
        "correct_answer": "Depth-first search",
        "explanation": "Depth-first search uses a stack explicitly or through recursion.",
    },
    {
        "id": "Q5",
        "question": "What prerequisite must hold before ordinary binary search is applied?",
        "selected_answer": "The input must be random",
        "correct_answer": "The input must be ordered",
        "explanation": "Binary search relies on ordered input to discard half of the search interval.",
    },
    {
        "id": "Q6",
        "question": "What must a hash table handle when two keys map to the same bucket?",
        "selected_answer": "Recursion",
        "correct_answer": "A collision",
        "explanation": "Collision handling resolves multiple keys mapped to one bucket.",
    },
    {
        "id": "Q7",
        "question": "In a binary search tree, where are keys smaller than a node normally stored?",
        "selected_answer": "In the right subtree",
        "correct_answer": "In the left subtree",
        "explanation": "The binary-search-tree ordering property places smaller keys on the left.",
    },
    {
        "id": "Q8",
        "question": "Which edge-weight condition is required by the standard Dijkstra algorithm?",
        "selected_answer": "All edges must be negative",
        "correct_answer": "Edge weights must be non-negative",
        "explanation": "Standard Dijkstra shortest-path processing assumes non-negative edge weights.",
    },
]


def request_json(method, path, payload=None):
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        BASE_URL + path,
        data=data,
        method=method,
        headers={"Content-Type": "application/json"} if data is not None else {},
    )
    with urllib.request.urlopen(request, timeout=15) as response:
        return response.status, json.loads(response.read().decode("utf-8"))


def main():
    run_id = str(uuid.uuid4())
    email = f"chapter6-weakness-{run_id}@example.invalid"

    create_status, notebook = request_json(
        "POST",
        "/create-notebook",
        {
            "email": email,
            "title": f"Chapter 6 Weakness Selection {run_id}",
        },
    )
    notebook_id = notebook["id"]

    breakdown = [
        {
            "question": item["question"],
            "selected_answer": item["selected_answer"],
            "correct_answer": item["correct_answer"],
            "explanation": item["explanation"],
            "is_correct": False,
        }
        for item in CONTROLLED_MISTAKES
    ]
    # Submit one exact duplicate to verify question-text deduplication.
    breakdown.append(dict(breakdown[0]))

    save_status, save_response = request_json(
        "POST",
        "/save-quiz-result",
        {
            "notebook_id": notebook_id,
            "score": 0,
            "correct_answers": 0,
            "total_questions": len(CONTROLLED_MISTAKES),
            "percentage": 0,
            "quiz_data": [],
            "breakdown": breakdown,
            "quiz_title": "Chapter 6 Controlled Weakness Selection Setup",
        },
    )

    retrieve_status, retrieve_response = request_json(
        "GET",
        f"/get-notebook-mistakes?notebook_id={notebook_id}",
    )

    actual_mistakes = retrieve_response.get("mistakes", [])
    actual_questions = [item.get("question") for item in actual_mistakes]
    expected_stored_questions = [item["question"] for item in reversed(CONTROLLED_MISTAKES)]
    expected_selected_questions = expected_stored_questions[:6]
    actual_selected_questions = actual_questions[:6]

    storage_pass = (
        create_status == 200
        and save_status == 200
        and retrieve_status == 200
        and retrieve_response.get("mistakes_count") == 8
        and actual_questions == expected_stored_questions
    )
    duplicate_handling_pass = actual_questions.count(CONTROLLED_MISTAKES[0]["question"]) == 1
    selection_pass = actual_selected_questions == expected_selected_questions

    manual_request = {
        "method": "POST",
        "url": f"{BASE_URL}/generate-weakness-drill",
        "headers": {"Content-Type": "application/json"},
        "body": {
            "notebook_id": notebook_id,
            "output_language": "English",
            "sources": [],
        },
    }
    MANUAL_REQUEST_FILE.write_text(json.dumps(manual_request, indent=2), encoding="utf-8")

    evidence = {
        "run_id": run_id,
        "notebook": {
            "id": notebook_id,
            "title": notebook.get("title"),
            "user_email": notebook.get("user_email"),
            "sources": notebook.get("sources"),
        },
        "production_persistence_endpoint": "POST /save-quiz-result",
        "production_retrieval_endpoint": "GET /get-notebook-mistakes",
        "production_generation_endpoint": "POST /generate-weakness-drill",
        "implemented_distinctness_rule": "Store an incorrect item only when its stripped, non-empty question is not exactly equal to an existing mistake question.",
        "implemented_insertion_rule": "Each newly distinct mistake is inserted at index 0 of the notebook's embedded mistakes_bank list.",
        "implemented_selection_rule": "top_mistakes = mistakes[:6]",
        "submitted_distinct_mistakes": CONTROLLED_MISTAKES,
        "submitted_breakdown_item_count_including_duplicate": len(breakdown),
        "stored_mistake_count": retrieve_response.get("mistakes_count"),
        "stored_mistakes_in_actual_order": actual_mistakes,
        "expected_stored_question_order": expected_stored_questions,
        "expected_selected_first_six_questions": expected_selected_questions,
        "actual_selected_first_six_questions": actual_selected_questions,
        "storage_result": "PASS" if storage_pass else "FAIL",
        "duplicate_handling_result": "PASS" if duplicate_handling_pass else "FAIL",
        "selection_logic_result": "PASS" if selection_pass else "FAIL",
        "generation_status": "NOT_RUN_REQUIRES_GEMINI",
        "generated_drill_result": None,
        "contextual_relevance_result": "PENDING_MANUAL_GENERATION_AND_REVIEW",
        "manual_generation_request_file": str(MANUAL_REQUEST_FILE),
        "interpretation_limit": "Selection is positional first-six selection. It is not frequency-weighted, recency-scored, or adaptively scored.",
        "raw_endpoint_statuses": {
            "create_notebook": create_status,
            "save_quiz_result": save_status,
            "get_notebook_mistakes": retrieve_status,
        },
        "save_quiz_result_response": save_response,
    }
    EVIDENCE_FILE.write_text(json.dumps(evidence, indent=2), encoding="utf-8")

    print(f"Notebook ID: {notebook_id}")
    print(f"Stored mistakes: {retrieve_response.get('mistakes_count')}")
    print(f"Storage result: {evidence['storage_result']}")
    print(f"Duplicate handling result: {evidence['duplicate_handling_result']}")
    print(f"Selection logic result: {evidence['selection_logic_result']}")
    print("Selected first six, in order:")
    for index, question in enumerate(actual_selected_questions, 1):
        print(f"  {index}. {question}")
    print("Generation status: NOT_RUN_REQUIRES_GEMINI")
    print(f"Evidence: {EVIDENCE_FILE}")
    print(f"Manual request: {MANUAL_REQUEST_FILE}")


if __name__ == "__main__":
    main()
