#!/usr/bin/env python3
"""Add entries to repos.yaml for repositories that aren't managed yet.

Lists the owner's repositories with the GitHub CLI and skips archived ones,
forks, and anything already in repos.yaml. Each new entry copies the
repository's current visibility, description, homepage, topics and
issue/discussion settings, so the first plan only changes the baseline.

Needs `gh` (authenticated). Prints the names of the repositories it added, one
per line.
"""

import argparse
import json
import re
import subprocess
import sys

REPOS_YAML = "repos.yaml"

# Options in the order they're written. See modules/repository/variables.tf.
OPTIONS = [
    "visibility",
    "description",
    "homepage_url",
    "topics",
    "is_template",
    "has_issues",
    "has_discussions",
    "required_status_checks",
    "merge_queue",
]

# A top-level key: a repository name, bare or JSON-quoted.
KEY_RE = re.compile(r'^("(?:[^"\\]|\\.)*"|[^\s#"][^:]*):\s*$')
PLAIN_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9 ._/()+-]*$")
NUMBER_RE = re.compile(r"^[-+]?[0-9._]+([eE][-+]?[0-9]+)?$")
RESERVED = {"true", "false", "yes", "no", "on", "off", "y", "n", "null"}


def scalar(value):
    """Render a YAML scalar, quoting strings unless they're unambiguous.

    A JSON string is also a valid YAML double-quoted string, so json.dumps
    handles every character that needs escaping.
    """
    if isinstance(value, bool):
        return "true" if value else "false"
    plain = (
        PLAIN_RE.match(value)
        and value == value.strip()
        and value.lower() not in RESERVED
        and not NUMBER_RE.match(value)
    )
    return value if plain else json.dumps(value, ensure_ascii=False)


def render(name, options):
    lines = [f"{scalar(name)}:"]
    for key in sorted(options, key=OPTIONS.index):
        value = options[key]
        if isinstance(value, list):
            lines.append(f"  {key}:")
            lines += [f"    - {scalar(item)}" for item in value]
        else:
            lines.append(f"  {key}: {scalar(value)}")
    return [line + "\n" for line in lines]


def options_for(repo):
    """The options for a repository: only those that differ from the defaults."""
    options = {"visibility": repo["visibility"].lower()}
    if repo.get("description"):
        options["description"] = repo["description"]
    if repo.get("homepageUrl"):
        options["homepage_url"] = repo["homepageUrl"]
    topics = [t["name"] for t in repo.get("repositoryTopics") or []]
    if topics:
        options["topics"] = topics
    if repo.get("isTemplate"):
        options["is_template"] = True
    if not repo.get("hasIssuesEnabled", True):
        options["has_issues"] = False
    if repo.get("hasDiscussionsEnabled"):
        options["has_discussions"] = True
    return options


def key_lines(lines):
    """Map line index to repository name for every top-level key."""
    keys = {}
    for i, line in enumerate(lines):
        m = KEY_RE.match(line.rstrip("\n"))
        if m:
            key = m.group(1)
            keys[i] = json.loads(key) if key.startswith('"') else key.strip()
    return keys


def insert(lines, name, options):
    """Insert an entry before the first existing entry that sorts after it."""
    entry = render(name, options)
    for i, key in key_lines(lines).items():
        if key.lower() > name.lower():
            lines[i:i] = entry + ["\n"]
            return
    if lines and not lines[-1].endswith("\n"):
        lines[-1] += "\n"
    lines += ["\n"] + entry


def github_repos(owner):
    fields = (
        "name,visibility,isArchived,isFork,isTemplate,description,homepageUrl,"
        "repositoryTopics,hasIssuesEnabled,hasDiscussionsEnabled"
    )
    out = subprocess.run(
        ["gh", "repo", "list", owner, "--limit", "1000", "--json", fields],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    return json.loads(out)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--owner", default="horrell-consulting")
    args = parser.parse_args()

    with open(REPOS_YAML) as f:
        lines = f.readlines()
    known = set(key_lines(lines).values())

    new = sorted(
        (
            r
            for r in github_repos(args.owner)
            if not r["isArchived"] and not r["isFork"] and r["name"] not in known
        ),
        key=lambda r: r["name"].lower(),
    )
    if not new:
        return 0

    for repo in new:
        insert(lines, repo["name"], options_for(repo))
    with open(REPOS_YAML, "w") as f:
        f.writelines(lines)

    for repo in new:
        print(repo["name"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
