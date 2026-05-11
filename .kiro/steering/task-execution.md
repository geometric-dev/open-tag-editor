---
inclusion: auto
description: Rules for how to execute spec tasks using subagent delegation, parallelisation, and validation
---

# Task Execution Strategy

## Subagent Delegation

When implementing spec tasks, delegate work to subagents whenever possible:

- **Prefer smaller models**: Use subagents for self-contained implementation units (single files, single functions, isolated tests).
- **Keep context sharp**: Provide only the files and line ranges directly relevant to the subtask. Don't dump entire specs — extract the specific requirement, interface, or data model the agent needs.
- **Parallelise aggressively**: If two or more subtasks have no dependency on each other's output, dispatch them as parallel subagent calls.
- **Orchestrate in the main thread**: The main agent handles sequencing, dependency resolution, checkpoint validation, and stitching results together. It reads outputs, verifies correctness, and dispatches the next wave.

## Subagent Prompt Structure (keep under ~2000 tokens)

A good subagent prompt contains exactly:
1. **File to create** — full path and purpose (one sentence)
2. **Interface to implement** — paste the abstract class or function signature
3. **Data models** — paste only the types the code will import/use
4. **Behaviour bullets** — 3-7 bullet points of what the implementation must do
5. **Style rules** — 3-4 key rules (doc comments, trailing commas, single quotes, etc.)
6. **Imports** — list the exact import paths so the agent doesn't guess

Do NOT include: full design documents, unrelated specs, PRDs, or context about other components.

## Parallelisation Rules

**Always parallel:**
- Independent files with no import dependency on each other
- Platform-specific configurations (Windows/macOS/Linux)
- Property tests and unit tests for different components
- Types/enums files alongside loader/utility files

**Always sequential:**
- Tasks that import the output of a previous task (e.g., bindings generation depends on header file)
- Service implementations that depend on a mapper/utility created in the same wave
- Integration wiring (service providers) after all services exist

**Combine into one subagent call:**
- Multiple subtasks targeting the same file (e.g., writeTags + writeAlbumArt + writeTagsBatch all live in the writer service)
- A class and its closely-coupled helper (e.g., reader service + its internal `_AudioProperties` class)

## Validation Cadence

- Run `getDiagnostics` after each wave of parallel subagent completions
- Fix lint/compile issues immediately before dispatching the next wave
- Run `dart analyze` on the full affected directory after completing a top-level task group
- If a subagent produces code with diagnostics errors, fix inline rather than re-dispatching

## Task Execution Order

1. **Read the full tasks.md** to understand dependencies
2. **Identify the first wave** of independent subtasks
3. **Mark all as in_progress** and dispatch subagents in parallel
4. **Validate** outputs (diagnostics check)
5. **Mark completed** and identify the next wave
6. **Repeat** until the task group is done
7. **Skip optional tasks** (marked with `*`) during initial implementation — do them in a separate pass if requested

## Model Selection

- **Default to general-task-execution subagents** for straightforward file creation, boilerplate, and well-specified implementations.
- **Escalate to a more capable model** (use the main thread directly) when:
  - The task requires cross-file reasoning or architectural decisions
  - A subagent returns code with diagnostics errors or nonsensical output
  - The prompt would exceed ~2000 tokens of necessary context
  - The task involves complex FFI, concurrency, or algorithmic logic
  - The first attempt failed — don't retry with the same approach, bump up
- **On subagent failure**: If a subagent produces broken code, don't re-dispatch to the same agent with a tweaked prompt. Fix it in the main thread or implement it directly. Keep momentum over retry loops.
- **Quality over speed**: A single correct implementation is faster than two broken attempts. When in doubt about whether a task is too complex for a subagent, do it in the main thread.

## Subagent Strategy Annotations in Tasks

When writing tasks.md for a spec, annotate each leaf task (numbered subtask) with a `_Subagent:_` line indicating:
1. Whether the task can be delegated to a subagent or must run in the main thread
2. The recommended execution approach

Use this format after the requirements line of each subtask:

```
  - [ ] 1.1 Task title
    - Description bullets...
    - _Requirements: X.Y_
    - _Subagent: delegate_ — or — _Subagent: main thread (reason)_
```

**Classification rules:**
- **`delegate`** — Self-contained file creation, single-class implementation, boilerplate, tests, models, enums, isolated utilities. These have clear inputs/outputs and don't require cross-file reasoning.
- **`main thread (cross-file wiring)`** — Tasks that import outputs from multiple other tasks, wire providers together, or require reading existing code to integrate correctly.
- **`main thread (complex logic)`** — Tasks involving algorithmic complexity, FFI, concurrency, or multi-step reasoning that would exceed a subagent's reliable capability.
- **`main thread (architectural)`** — Tasks requiring design decisions, refactoring existing code, or understanding broader system context.

This annotation guides the orchestrator during execution — it knows immediately which tasks to dispatch vs. handle directly, without re-analyzing each time.

## Efficiency Patterns Learned

- When ffigen or similar tools require unavailable system dependencies (LLVM, native compilers), generate the output file manually rather than blocking. The generated file is committed to source control anyway.
- For test fixtures that require binary files (audio samples), create a README with generation instructions and a corrupt.bin placeholder. Don't block implementation on fixture generation.
- When a task says "update X" and the file is small, include the full replacement content in the subagent prompt rather than asking it to do a surgical edit. Reduces errors.
- Combine tightly-coupled tasks (same file, same class) into one subagent call. Splitting them creates merge conflicts and wasted round trips.
- Use `contextFiles` parameter on `invokeSubAgent` for providing interface files. Use inline code blocks in the prompt for small snippets the agent needs to implement against.

## Post-Implementation Audit Checklist

After subagents complete a wave of work, the main thread should verify:

1. **Allocator consistency** — `toNativeUtf8()` uses `malloc` by default → free with `malloc.free()`. Only use `calloc.free()` for memory allocated with `calloc<>()`. Never mix allocators.
2. **Struct field types** — Binary data fields (`char *` for raw bytes) must be `Pointer<Uint8>`, not `Pointer<Utf8>`. Only use `Pointer<Utf8>` for actual null-terminated C strings.
3. **API contract verification** — When wrapping a C API, verify the actual behaviour of key functions (e.g., does passing NULL clear a field or crash?) against the header documentation before relying on it.
4. **Unused imports** — Subagents sometimes include imports they don't use. Run diagnostics to catch these.
5. **Stub completeness** — If a method is stubbed with `throw UnimplementedError()` or similar, document it clearly with a TODO and ensure the stub is tracked for follow-up.

## Final Checkpoint Requirements

Before marking the final checkpoint task as complete and handing back to the user, ALL of the following must pass:

1. **`flutter analyze`** — must complete with zero errors (warnings and infos from pre-existing code are acceptable, but no new warnings may be introduced by the implemented feature)
2. **`flutter test`** — must complete with all tests passing (zero failures)
3. **`flutter build windows`** — must complete successfully (substitute the target platform as appropriate: `windows`, `macos`, `linux`)

If any of these fail, fix the issues before marking the checkpoint complete. Do not hand back to the user with a broken build.

When delegating FFI work to subagents, always include these rules in the prompt:

- `toNativeUtf8()` allocates with `malloc` → always free with `malloc.free()`
- `calloc<StructType>()` allocates with `calloc` → free with `calloc.free()`
- Binary data pointers use `Pointer<Uint8>`, string pointers use `Pointer<Utf8>`
- Null-check every pointer returned from native code before dereferencing
- Free all native memory in `try/finally` blocks
- Never call `.toDartString()` on a pointer that holds binary data
