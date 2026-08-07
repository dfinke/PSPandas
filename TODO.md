# PSPandas Roadmap

Reviewed against commit `5e7e5a4` on 2026-08-07. The current baseline passes all 34 Pester tests and imports cleanly.

This roadmap is ordered by recommended priority. Correctness and a coherent object-flow contract come before broader pandas-style feature coverage.

## Current foundation

PSPandas now provides:

- An ordered, pipeline-friendly DataFrame with ordinary PowerShell row objects.
- Typed flat-file import through PSFlatFile.
- Excel first-sheet, named-sheet, and tab-completable workbook import through ImportExcel.
- Filtering, column selection, sorting, calculated columns, grouping, aggregation, and joins.
- Indexed column objects with scalar operations.
- Structured profiling through `Get-PSDataFrameProfile` / `Describe`.
- Interactive DataFrame and profile formatting, 12 runnable examples, and 52 Pester tests.
- Wide pivot tables with multiple row/column dimensions, multiple values, per-value or advanced aggregates, fill values, sorting, margins, structured reshape metadata, and hierarchical outline reporting.

The earlier roadmap items for typed import, ImportExcel integration, workbook access, profiling, practical examples, and wide pivot tables are complete.

## Lessons from the pandas implementation

The pandas implementation is valuable as an architectural reference, not as a template to port literally. Its mature design separates the public `DataFrame` / `Series` objects from internal storage, gives extension data types their own behavioral contract, centralizes grouping codes and aggregation dispatch, builds pivot tables from grouping plus reshape operations, routes delimited input through parser engines, and defines copy behavior explicitly.

PSPandas should adopt the following ideas in PowerShell-native form:

- **Stable result-shape contracts.** pandas distinguishes operations returning another frame from those returning a one-dimensional `Series`. PSPandas should publish the equivalent contract for DataFrame, column, group, workbook, and ordinary-row results so pipeline composition is never surprising. This lets users know whether the next pipeline command receives one composable frame or a stream of rows without having to inspect implementation details.
- **A column-behavior contract.** pandas extension arrays own type-specific behavior such as missing-value detection and grouped operations. PSPandas needs a lighter internal adapter for .NET/PowerShell types covering null detection, comparison, hashing, numeric promotion, aggregation, conversion, and display. Centralizing these rules prevents `Describe`, `Summarize`, joins, and indexed column methods from producing different answers for the same values.
- **Reusable grouping machinery.** pandas represents groups with reusable codes/indices and implements `pivot_table` by grouping, aggregating, and unstacking. PSPandas should share one factorization/grouping engine across `Group-PSDataFrame`, `Measure-PSDataFrame`, `Summarize`, pivot, duplicate detection, and quality checks. One engine gives all these features the same key equality, null handling, ordering, and performance characteristics.
- **Reader providers rather than command proliferation.** pandas readers select a parsing engine behind a stable public function. `Import-PSDataFrame` should similarly route by source type and capability, keeping PSFlatFile, ImportExcel, and future PSDolt support behind adapters with consistent validation and diagnostics. Users retain one discoverable import experience while optional integrations can evolve without coupling their dependencies to the DataFrame core.
- **Explicit copy and mutation semantics.** pandas Copy-on-Write exists because shared data can otherwise produce surprising mutation. PSPandas should document immutable/frame-copy behavior now and introduce shared or columnar storage only behind a clear ownership contract. This protects users from a transformation unexpectedly changing its source frame while leaving room for later memory and speed improvements.
- **Contract tests for extension points.** pandas supplies reusable tests for extension arrays. PSPandas should create conformance tests for future reader providers, type adapters, and storage implementations. Every new provider or implementation would then prove that it preserves the same null, ordering, error, and result-shape behavior before it is accepted.

Deliberately defer these pandas concepts unless a concrete PSPandas use case justifies them:

- An implicit row index, automatic label alignment, or hierarchical `MultiIndex`. PowerShell users naturally work with named object properties and explicit key columns; hidden alignment would make object flow harder to reason about.
- A pandas-style `BlockManager`. PSPandas should first introduce a narrow storage interface and optimize measured hot paths. Reproducing pandas' block layout would add complexity before benchmarks demonstrate a need.
- A separate `Read-*` command for every format. One discoverable `Import-PSDataFrame` with provider-based routing is more idiomatic in PowerShell.
- DataFrame subclassing as the integration model. Composition, provider adapters, and explicit metadata are safer boundaries for PSFlatFile, ImportExcel, PSDolt, and future integrations.

## Lessons from PowerShellPivot

PowerShellPivot is a direct design predecessor to PSPandas' reshape work. Its README explicitly draws from Excel pivot tables and pandas pivot functionality, and `Invoke-PSMelt` is documented as an adaptation of pandas melt. The original pivot/melt implementation was later complemented by community-contributed `ConvertTo-CrossTab`, `Get-Subtotal`, and grouped-object statistical methods, so the repository contains both pandas-inspired and PowerShell-community approaches to the same analytical problem.

Carry these proven ideas forward:

- **PowerShell-friendly pivot vocabulary.** `New-PSPivotTable` established understandable parameters such as index, columns, values, aggregate function, fill value, and missing-value label. PSPandas should retain that mental model while using plural parameter names consistently and returning a DataFrame rather than plain row objects.
- **Melt as the inverse operation.** `Invoke-PSMelt` supports identifier columns, selected value columns, custom variable/value names, wildcard exclusions, dissimilar row shapes, and direct pipeline input. Those are mature requirements for a PSPandas long-form reshape command, and its row-at-a-time implementation demonstrates that melt can stream without first materializing a second complete source collection.
- **Accumulator-style aggregate extensions.** PowerShellPivot's `BaseStats` subclasses expose an `AddToMeasure()` / `Result()` lifecycle and make aggregate names discoverable through argument completion. PSPandas should generalize that idea into an internal aggregate registry so pivot, `Summarize`, and indexed columns share built-ins and can later accept custom accumulators without hard-coding every function.
- **Separate aggregation from reshape.** The community-added `Get-Subtotal` plus `ConvertTo-CrossTab` path first resolves duplicate row/column combinations and then widens them. That composition aligns with pandas' groupby/aggregate/unstack implementation and supports the roadmap decision to build pivot on one reusable grouping engine.
- **A valuable edge-case test inventory.** PowerShellPivot has 85 passing tests covering pipeline input, missing dimensions, null/NaN measures, fill values, invalid or excluded properties, multiple measures, aggregate naming, crosstabs, and configurable melt output. PSPandas should translate those scenarios into DataFrame-focused conformance tests rather than starting the pivot test matrix from scratch.

Improve these behaviors rather than copying them:

- Missing source columns currently produce warnings and are removed; PSPandas should fail clearly because silently changing the requested analysis can create plausible but incomplete results.
- PowerShellPivot converts measures to `Double`, represents absent cells with `NaN`, and sometimes injects the fill value before aggregation. PSPandas should preserve its numeric/type policy and apply `-FillValue` only to missing output combinations after aggregation.
- String-based or nested-hashtable grouping should be replaced by PSPandas' typed factorization contract, including explicit null-key and equality behavior.
- Multiple index/column dimensions are constrained or unfinished in PowerShellPivot. PSPandas should design composite dimensions from the start, even if the first release limits the number of column dimensions deliberately.
- The MathNet assembly enables broad statistics but should not become a required dependency for core reshape. Median, variance, quartiles, and other advanced statistics can be optional aggregate providers after the built-in numeric contract is stable.
- PowerShellPivot exposes several overlapping ways to aggregate and widen data. PSPandas should provide one canonical implementation with concise aliases, preventing `Summarize`, cross-tab, and pivot from drifting semantically.

Recommended warning-free command surface:

```powershell
# Canonical approved-verb command, with Pivot / Pivot-PSDataFrame aliases.
$orders | ConvertTo-PSDataFrameWide -Index State -Columns Channel -Values Amount -Aggregate Sum

# Canonical approved-verb command, with Melt alias.
$wide | ConvertTo-PSDataFrameLong -Id State -Columns Online, Store -Name Channel -Value Amount
```

`Pivot-PSDataFrame` is a natural phrase but `Pivot` is not an approved PowerShell verb. Making `ConvertTo-PSDataFrameWide` canonical and exposing `Pivot` / `Pivot-PSDataFrame` as aliases preserves discoverability without reintroducing import warnings. The same pattern gives pandas users a familiar `Melt` alias while keeping `ConvertTo-PSDataFrameLong` idiomatic and explicit.

## 1. Correctness and data-semantics hardening

This is the next recommended milestone.

### Join correctness

Right and full joins currently produce `$null` for the join key on unmatched right-side rows. The key exists on the right row and should be preserved. The current test suite encodes the incorrect behavior, so both implementation and expectations must change together.

Also define and test join behavior for duplicate keys, composite keys, null keys, case sensitivity, column-name collisions after suffixing, and stable output ordering.

Success criteria:

- Unmatched right/full rows retain every join-key value.
- Inner, left, right, and full joins have a documented, consistent ordering contract.
- Duplicate and many-to-many keys produce predictable row counts.
- Composite/null keys and suffix collisions have explicit behavior and regression tests.

### Numeric precision and type preservation

Column operations, aggregates, and profiles currently convert numeric values to `Double`. This is convenient but can lose precision for `Decimal`, currency data, large integers, and mixed numeric types.

Define one numeric policy shared by `$frame['Amount'].Sum()`, `Measure-PSDataFrame`, concise `Summarize`, and `Describe`.

Implement this through a small internal column-behavior contract rather than scattered type checks. The first built-in adapters should cover integral values, floating-point values, `Decimal`, Boolean, text, `DateTime`, `DateTimeOffset`, `DateOnly`, null/all-null columns, and mixed objects. The contract should define `IsNull`, equality/hash behavior, ordering, supported reductions, promotion, and formatting.

Success criteria:

- Decimal/currency sums and bounds preserve meaningful precision.
- Integer overflow and mixed numeric-type promotion rules are explicit.
- Null and empty numeric behavior remains consistent across every API.
- Scalar operations, summaries, and profile statistics return compatible results for the same column.
- Every built-in type adapter passes the same conformance tests for nulls, comparisons, reductions, empty input, and unsupported operations.

### Missing-value and equality policy

Formalize the treatment of `$null`, `DBNull`, empty strings, whitespace, and missing properties. Define how equality works for grouping, joins, distinct counts, and mixed values.

pandas demonstrates why missing-value behavior cannot be separated from type behavior: its null representation and preservation rules differ by dtype. PSPandas does not need multiple public null sentinels, but it does need one centralized policy that type adapters and all hash/equality operations obey.

Success criteria:

- A concise policy is documented and tested across construction, profiling, grouping, aggregation, and joins.
- No operation silently converts empty text to null or coerces incompatible values unless explicitly requested.

## 2. Unify import, profiling, and object flow

`Import-PSDataFrame` now understands typed flat files and Excel workbooks, but direct-path `Describe` and `ConvertTo-PSDataFrame` still use the older flat-file reader path. Consolidate file handling behind one internal reader contract.

Model the contract as a registry of reader providers selected by extension or explicit format. A provider reports supported options, validates incompatible parameters early, loads ordinary typed row objects, and attaches explicit source metadata such as path and worksheet. Core DataFrame construction remains independent of optional modules.

Recommended behavior:

```powershell
Import-PSDataFrame .\sales.csv
Import-PSDataFrame .\sales.xlsx -WorksheetName Orders
Describe .\sales.xlsx -WorksheetName Orders
```

Keep `ConvertTo-PSDataFrame` focused on converting pipeline objects. Retain path input only as documented compatibility behavior or begin a deliberate deprecation path.

Add multiple-path support only with clear cardinality:

```powershell
Import-PSDataFrame -Path .\Jan.csv, .\Feb.csv   # one DataFrame per path
Import-PSDataFrame -Path $files -Combine        # explicit concatenation
```

Success criteria:

- One reader-routing implementation powers import and direct-path profiling.
- Excel profiling accepts worksheet selection without an intermediate assignment.
- Multiple paths never merge silently; explicit combination validates schema and ordering.
- Optional PSFlatFile and ImportExcel dependencies fail with actionable messages and are covered in CI without sibling-repository assumptions.
- Reader providers have reusable conformance tests for routing, option validation, empty input, missing dependencies, metadata, and failure messages.
- End-to-end examples cover import, profile, transform, and handoff to `Export-Excel`, ordinary PowerShell objects, and later PSDolt integration.

## 3. Improve frame-native row ergonomics

The DataFrame must remain a single pipeline object so transformations compose correctly. `.Rows` and `ConvertFrom-PSDataFrame` are valid explicit exits to ordinary row flow, but common row inspection should not feel low-level.

Review and improve:

- Frame-preserving first/last/slice operations.
- Whether `Get-PSDataFrameHead` should gain `-AsDataFrame` while preserving its current row output.
- A concise method or command surface for `$frame.Head(3)`-style interactive use.
- Consistent help explaining when commands return a DataFrame versus ordinary rows or group objects.
- A documented result-shape matrix covering DataFrame, column, workbook, grouped result, profile rows, and ordinary object output.

Success criteria:

- Users can preview or slice rows without reaching into `.Rows` for routine work.
- Frame-returning operations remain composable with `Summarize`, `Describe`, joins, and other transformations.
- The DataFrame itself is not made implicitly enumerable in a way that breaks pipeline binding.

## 4. Add analytical completeness

### Pivot and reshape

Wide pivot support is complete through the warning-free canonical `ConvertTo-PSDataFrameWide` command and its `Pivot` / `Pivot-PSDataFrame` aliases:

```powershell
$orders | ConvertTo-PSDataFrameWide -Index State -Columns Channel -Values Amount -Aggregate Sum
$orders | Pivot -Index State -Columns Channel -Values Amount -Aggregate Sum
```

The implementation supports positional index/column/value arguments with Sum by default, multiple index and column dimensions, multiple values, uniform or per-value aggregates, advanced named/scriptblock aggregates, post-aggregation fill values, sorting, margins recomputed from source rows, explicit `-Unique` pivots, structured flattened-column metadata, and an `-Outline` view that hierarchically renders multiple index levels without changing the typed rows.

Remaining reshape work:

- Add `ConvertTo-PSDataFrameLong`, with a concise `Melt` alias, when long-form reshape becomes the next analytical priority.
- Use retained pivot metadata when available so generated columns can be reversed without parsing flattened names; also support ordinary wide frames with explicit identifier/value-column parameters.
- Consolidate pivot's typed factorization with `Group-PSDataFrame` and `Summarize` after the shared missing/equality contract is finalized.
- Extend the aggregate registry beyond Sum, Count, Average, Min, and Max only after numeric precision and extension-provider contracts are settled.

### Time-aware summaries

Allow direct grouping by date parts without manually adding helper columns.

```powershell
$orders | Summarize -ByDate OrderDate -DatePart Year, Month -Sum Amount
```

Success criteria:

- Support year, quarter, month, week, and day for DateTime, DateTimeOffset, and DateOnly.
- Preserve chronological ordering and clearly name generated grouping columns.
- Define null, timezone, invalid, and mixed-date behavior.

## 5. Turn profiling into data-quality and cleaning workflows

Build on `Describe` with machine-readable checks for missing values, duplicate keys, mixed types, invalid ranges, and suspicious values.

Potential direction:

```powershell
$data | Test-PSDataFrameQuality -Key OrderId
```

Add explicit cleaning operations only after the missing-value and coercion policies are settled: fill/replace nulls, drop rows or columns, rename columns, remove duplicates, and opt-in type conversion.

Success criteria:

- Findings include column/key, check type, severity, count, and samples.
- Thresholds and coercion rules are explicit and configurable.
- Cleaning commands preserve column order and provide predictable empty-input behavior.
- `Describe` can lead naturally into quality checks and a documented remediation workflow.

## 6. Performance, workbook scale, and release readiness

The current implementation is intentionally in-memory and copy-oriented. Profiling distinct values uses repeated linear searches, and `-AsWorkbook` eagerly imports every worksheet.

Improve scale deliberately:

- Replace quadratic distinct counting with a tested hash-based strategy that preserves equality semantics.
- Reduce unnecessary row and column copying in transformation chains.
- Introduce a narrow internal storage interface before changing representation. The existing row-object store remains the reference implementation; an optional column-oriented implementation must preserve the same public behavior.
- Define whether transformations copy rows, share immutable values, or use copy-on-write before any shared-storage optimization. Never allow one derived frame to mutate another invisibly.
- Evaluate lazy worksheet loading for large workbooks while retaining tab completion and predictable errors.
- Add benchmarks for 10K, 100K, and 1M rows and for multi-sheet workbooks.
- Evaluate moving the in-memory `Add-Type` definitions to a versioned compiled assembly before a stable release, improving module reload and packaging behavior.

Release engineering success criteria:

- CI runs Pester on supported PowerShell/platform combinations.
- Optional PSFlatFile and ImportExcel integration tests run in a defined matrix.
- Reader-provider, type-adapter, and storage implementations pass reusable conformance suites.
- PSScriptAnalyzer has a project configuration that distinguishes deliberate public aliases from actionable warnings.
- The manifest includes complete project/repository metadata, versioning policy, license, and release notes.
- A clean installation from a module path or gallery package runs every non-optional example without repository-relative assumptions.

## Recommended implementation sequence

1. Fix right/full join keys and expand the join contract tests.
2. Define the column-behavior contract, including numeric promotion and missing/equality semantics.
3. Publish and test the result-shape matrix for every exported command and alias.
4. Route import and direct-path profiling through reader providers.
5. Add explicit multi-file and combine semantics.
6. Consolidate reusable grouping/factorization internals across grouping, summaries, and the completed pivot implementation.
7. Add time-aware summaries using the same grouper contract.
8. Add quality checks and explicit cleaning commands.
9. Improve frame-native row slicing and inspection alongside the result-shape contract.
10. Add long-form reshape / `Melt` when it becomes the next analytical priority.
11. Introduce a storage boundary, benchmark hot paths, and optimize without changing public semantics.
12. Add provider/adapter/storage conformance suites and complete CI/package/release infrastructure.

## Deliberate non-goals for now

- A literal or complete port of Python pandas.
- An implicit row index, automatic label alignment, or `MultiIndex` before an explicit PowerShell use case requires them.
- A pandas-style block storage engine before a storage abstraction and benchmarks justify it.
- Silent schema coercion or implicit merging of files and worksheets.
- A lazy query engine or distributed execution model before correctness contracts and benchmarks are established.
- PSDolt-specific coupling inside the core DataFrame model; ordinary object flow should remain the integration boundary.

## pandas implementation references

- [DataFrame implementation](https://github.com/pandas-dev/pandas/blob/main/pandas/core/frame.py): public frame construction, internal manager boundary, and frame-to-Series result construction.
- [Internal managers](https://github.com/pandas-dev/pandas/blob/main/pandas/core/internals/managers.py): two-dimensional block storage and block-level operation dispatch.
- [Extension architecture](https://pandas.pydata.org/docs/development/extending.html): extension arrays/dtypes, accessors, construction contracts, and reusable extension tests.
- [Grouping internals](https://github.com/pandas-dev/pandas/blob/main/pandas/core/groupby/ops.py): reusable grouping codes, indices, splitters, and aggregate dispatch.
- [Pivot implementation](https://github.com/pandas-dev/pandas/blob/main/pandas/core/reshape/pivot.py): pivot-table composition from groupby, aggregation, and unstack.
- [Delimited reader implementation](https://github.com/pandas-dev/pandas/blob/main/pandas/io/parsers/readers.py): a stable reader surface backed by selectable parser engines.
- [Missing-data semantics](https://pandas.pydata.org/docs/user_guide/missing_data.html): type-dependent null representation and detection.
- [Copy-on-Write design](https://pandas.pydata.org/docs/development/copy_on_write.html): explicit ownership semantics and reference tracking for shared data.
