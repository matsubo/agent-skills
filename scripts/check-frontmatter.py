#!/usr/bin/env python3
"""Check the frontmatter and body budget of each SKILL.md given on the command line.

    scripts/check-frontmatter.py skills/release/SKILL.md ...

Prints one tab-separated `check-id<TAB>path<TAB>message` finding per violation and exits
0 regardless; audit.sh counts the findings and decides the exit status.

Every check here is one that `claude plugin validate --strict` accepts. That was measured
against deliberately broken skills, not assumed: --strict rejects a missing frontmatter
block, unparseable YAML and a missing `description`, but accepts a missing `name`, a
`name` that violates the specification's charset, a `name` that disagrees with its
directory, and a `description` of any length.
"""
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")

# https://agentskills.io/specification — 1-64 chars, lowercase alphanumerics separated by
# single hyphens.
NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
NAME_MAX = 64
DESCRIPTION_MAX = 1024
BODY_MAX_LINES = 500

FRONTMATTER_RE = re.compile(r"\A---\n(.*?)\n---\n?", re.DOTALL)


def check(path: Path) -> list[tuple[str, str]]:
    """Return (check-id, message) for every violation in one SKILL.md."""
    findings: list[tuple[str, str]] = []
    text = path.read_text(encoding="utf-8")

    match = FRONTMATTER_RE.match(text)
    if not match:
        return [("frontmatter-parse", "no YAML frontmatter block at the top of the file")]

    try:
        meta = yaml.safe_load(match.group(1))
    except yaml.YAMLError as error:
        detail = str(error).replace("\n", " ")
        return [("frontmatter-parse", f"frontmatter is not valid YAML: {detail}")]

    if not isinstance(meta, dict):
        return [("frontmatter-parse", "frontmatter is not a YAML mapping")]

    findings += check_name(meta.get("name"), path)
    findings += check_description(meta.get("description"))

    body_lines = text[match.end():].count("\n")
    if body_lines > BODY_MAX_LINES:
        findings.append((
            "body-length",
            f"body is {body_lines} lines, over the {BODY_MAX_LINES} line budget; "
            "move the excess into references/ and say when to read it",
        ))

    return findings


def check_name(name, path: Path) -> list[tuple[str, str]]:
    if name is None:
        return [("name-missing", "no `name` field")]
    if not isinstance(name, str):
        return [("name-missing", f"`name` is {type(name).__name__}, expected a string")]
    findings = []
    if not NAME_RE.match(name) or len(name) > NAME_MAX:
        findings.append((
            "name-charset",
            f"name {name!r} must be 1-{NAME_MAX} characters of lowercase letters, "
            "digits and single hyphens",
        ))
    directory = path.parent.name
    if name != directory:
        findings.append((
            "name-dir-mismatch",
            f"name {name!r} does not match its directory {directory!r}",
        ))
    return findings


def check_description(description) -> list[tuple[str, str]]:
    if description is None:
        return [("description-missing", "no `description` field")]
    if not isinstance(description, str):
        return [("description-missing",
                 f"`description` is {type(description).__name__}, expected a string")]
    if not description.strip():
        return [("description-missing", "`description` is empty")]
    length = len(description)
    if length > DESCRIPTION_MAX:
        return [("description-length",
                 f"description is {length} characters, over the {DESCRIPTION_MAX} maximum")]
    return []


def main(argv: list[str]) -> int:
    for argument in argv:
        path = Path(argument)
        for check_id, message in check(path):
            print(f"{check_id}\t{path}\t{message}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
