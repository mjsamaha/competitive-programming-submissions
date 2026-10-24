# Competitive Programming

My C++ competitive programming workspace.

This repository contains reusable C++ templates, algorithms,
data structures, and problem solutions from various online judges.

## Language and Tools

- Language: C++
- Standard: C++17
- Compiler: GCC (MSYS2/MinGW)
- Editor: Sublime Text
- Build and execution: PowerShell

## Repository Structure

| Directory | Purpose |
|---|---|
| `templates/` | Reusable C++ templates and snippets |
| `lib/` | Algorithms, data structures, mathematics, and strings |
| `platforms/` | Platform-specific problems and contest solutions |
| `tools/` | Build and development scripts |

## Commit Conventions

Use descriptive, consistent commit messages to keep the repository history organized and searchable.

### Format

`<type>(<scope>): <description>`

- **type:** The kind of change being made.
- **scope:** The platform, contest, or repository component affected.
- **description:** A short summary of the change.

### 1. Adding Individual Problem Solutions

**Single problem**

```bash
git commit -m "solution(codeforces): 4A - Watermelon"
git commit -m "solution(leetcode): 0001 - Two Sum"
git commit -m "solution(atcoder): abc001_a - Online Shopping"
```

**Multiple problems from the same platform**

```bash
git commit -m "solution(codeforces): add multiple problems"
git commit -m "solution(leetcode): add array problems"
```

### 2. Adding Contest Solutions

**Single contest**

```bash
git commit -m "contest(codeforces): Round 1050"
git commit -m "contest(atcoder): ABC001"
git commit -m "contest(leetcode): Weekly Contest 482"
```

**Updating or completing contest solutions**

```bash
git commit -m "contest(codeforces): add Round 1050 solutions"
git commit -m "contest(atcoder): complete ABC001 solutions"
```

### 3. Adding or Updating Templates

```bash
git commit -m "template(cpp17): add base template"
git commit -m "template(cpp17): add debugging utilities"
git commit -m "template(snippets): add common macros"
```

### 4. Adding or Updating Algorithms and Data Structures

```bash
git commit -m "lib(graph): implement Dijkstra's algorithm"
git commit -m "lib(data-structures): implement Fenwick tree"
git commit -m "lib(math): add modular arithmetic utilities"
git commit -m "lib(strings): implement KMP"
```

### 5. Repository Maintenance

```bash
git commit -m "docs: update repository README"
git commit -m "build: improve PowerShell runner"
git commit -m "chore: update gitignore"
git commit -m "refactor(template): simplify type aliases"
git commit -m "fix(codeforces): correct Square solution"
```

### Guidelines

- Use lowercase type and scope names.
- Keep descriptions concise and specific.
- Use official problem IDs and contest identifiers whenever possible.
- Use `solution` for individual problem submissions and `contest` for contest-related changes.
- Use `template` for reusable templates and snippets.
- Use `lib` for reusable algorithms and data structures.
- Use `docs`, `build`, `chore`, `refactor`, and `fix` for documentation, tooling, maintenance, restructuring, and bug fixes, respectively.
- Prefer one commit per problem or contest when practical.
- When committing multiple problems together, group related solutions in a single commit.
- Write commit messages in the imperative or descriptive style; avoid vague messages such as `updates`, `stuff`, or `changes`.

### Recommended Convention

Use the following format consistently:

`<type>(<scope>): <description>`

Examples:

- `solution(codeforces): 2094A - Square?`
- `contest(codeforces): add Round 1050 solutions`
- `template(cpp17): improve base template`
- `lib(graph): implement BFS`
- `build: add global C++ runner documentation`
- `docs: document commit conventions`


---

## Platforms

- [Codeforces](https://codeforces.com/)
- [LeetCode](https://leetcode.com/)
- [AtCoder](https://atcoder.jp/)
- [CodeAbbey](https://www.codeabbey.com/)
- [LightOJ](https://lightoj.com/)

## Compiling and Running

I've configured the .ps1 script to be executed globally from the terminal with the command name "runcpp"

From the repository root, run:

```powershell
runcpp [argument].cpp or [argument] (filename)