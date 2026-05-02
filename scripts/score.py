#!/usr/bin/env python3
"""
Reproduce the weighted comparison scores in README.md.

Run:  python3 scripts/score.py
"""

PROJECTS = [
    "claude-mem", "MemPalace", "memsearch",
    "mem-compiler", "supermemory", "cc-native", "cc-memory-arch",
]

# 16-dimension scores per project (0–10).
# Order of values matches PROJECTS list.
# Sources: project README / docs / public benchmarks (as of 2026-05).
# Disagreements welcome via GitHub issues.
SCORES = {
    1:  [10, 9, 9, 9, 8, 7, 4],    # ingestion automation
    2:  [9, 9, 10, 4, 8, 1, 2],    # retrieval methods (vector/full-text/hybrid)
    3:  [5, 10, 6, 0, 5, 0, 0],    # retrieval precision (public benchmark)
    4:  [10, 10, 10, 9, 9, 6, 8],  # persistence / cross-session continuity
    5:  [5, 10, 6, 7, 7, 3, 7],    # data model expressiveness
    6:  [3, 4, 3, 7, 8, 10, 10],   # deployment complexity (low = good)
    7:  [4, 4, 3, 7, 9, 10, 10],   # resource footprint (low = good)
    8:  [6, 7, 8, 10, 3, 10, 10],  # data portability / format openness
    9:  [6, 7, 10, 4, 5, 3, 3],    # interoperability across agents
    10: [5, 5, 4, 6, 8, 10, 8],    # installability / onboarding
    11: [4, 3, 5, 6, 4, 2, 9],     # data lifecycle management (compaction/GC)
    12: [4, 5, 5, 6, 4, 2, 9],     # deduplication / conflict resolution
    13: [4, 6, 4, 4, 4, 3, 9],     # deletion semantics
    14: [9, 7, 6, 5, 6, 4, 6],     # observability (logs/audit)
    15: [9, 10, 9, 9, 2, 10, 10],  # privacy / data residency
    16: [10, 10, 6, 5, 6, 10, 1],  # project maturity / community
}

# Weight set 1: IR / RAG industry convention
#   A. Functional capability    35%  (1–5)
#   B. Deployment / resources   20%  (6–10)
#   C. Governance / quality     20%  (11–14)
#   D. Privacy / maturity       25%  (15–16)
WEIGHTS_INDUSTRY = {
    1: 0.07, 2: 0.10, 3: 0.08, 4: 0.05, 5: 0.05,
    6: 0.06, 7: 0.04, 8: 0.05, 9: 0.03, 10: 0.02,
    11: 0.06, 12: 0.04, 13: 0.04, 14: 0.06,
    15: 0.10, 16: 0.15,
}

# Weight set 2: long-term cc personal user with curation pain
#   A. Functional        15%  (already covered by cc native + plugins)
#   B. Deployment        25%
#   C. Governance        40%  (the actual pain)
#   D. Privacy/maturity  20%  (community downweighted: not a quality signal)
WEIGHTS_PERSONAL = {
    1: 0.03, 2: 0.04, 3: 0.03, 4: 0.02, 5: 0.03,
    6: 0.07, 7: 0.05, 8: 0.06, 9: 0.04, 10: 0.03,
    11: 0.12, 12: 0.08, 13: 0.08, 14: 0.12,
    15: 0.10, 16: 0.10,
}

assert abs(sum(WEIGHTS_INDUSTRY.values()) - 1.0) < 1e-9
assert abs(sum(WEIGHTS_PERSONAL.values()) - 1.0) < 1e-9


def weighted_score(weights, project_idx):
    return round(sum(SCORES[d][project_idx] * w for d, w in weights.items()), 2)


def print_table(weights, title):
    rows = [(name, weighted_score(weights, i)) for i, name in enumerate(PROJECTS)]
    rows.sort(key=lambda r: -r[1])
    print(f"\n=== {title} ===")
    for rank, (name, score) in enumerate(rows, 1):
        print(f"  {rank}. {name:<18} {score:.2f}")


if __name__ == "__main__":
    print_table(WEIGHTS_INDUSTRY, "IR/RAG industry-convention weights")
    print_table(WEIGHTS_PERSONAL, "Personal cc user (governance-focused) weights")
