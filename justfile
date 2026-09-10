# Run `just` with no arguments to see the available tasks.
default:
    @just --list

# Everything CI runs, in the same order and through the same scripts.
ci: audit test validate

# Spec conformance, manifest consistency, unsafe content, eval well-formedness.
audit:
    ./scripts/audit.sh

# Prove each audit check still fires, against fixtures that violate exactly one rule each.
test:
    ./tests/audit_test.sh

# Defence in depth. Weaker than `just audit` — see the note in scripts/audit.sh.
validate:
    claude plugin validate . --strict
    claude plugin validate ./skills --strict

# Measure how reliably a skill's description triggers. Not in `ci`: costs money, and is read
# as a trigger rate over repeated runs rather than as pass/fail.
eval skill set="train":
    ./evals/run-trigger-eval.sh evals/{{skill}}/{{set}}_queries.json {{skill}}
