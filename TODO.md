# PSPandas Roadmap

This is a reviewable roadmap for the next stages of PSPandas. The items are ordered by recommended priority and are intentionally subject to user review before implementation.

## 1. Build an end-to-end real-data path

Connect the practical workflow from `ImportExcel` or `PSFlatFile` through `ConvertTo-PSDataFrame`, `Describe`, analysis and cleaning, and finally to `Export-Excel` or PSDolt.

Rationale: Validate PSPandas against realistic input and output boundaries, while demonstrating how it composes with the surrounding PowerShell data tools.

Suggested success criteria:

- Provide a documented, runnable example using representative real-data-shaped input.
- Preserve column order, types, nulls, and ordinary PowerShell object interoperability across the workflow.
- Demonstrate profiling, at least one cleaning/transformation step, analysis, and an output handoff.
- Keep ImportExcel, PSFlatFile, and PSDolt integrations optional rather than hard dependencies.

## 2. Add pivot-table support

Add an ergonomic API such as:

```powershell
Pivot-PSDataFrame -Index State -Columns Channel -Values Amount -Aggregate Sum
```

Rationale: Pivoting is a high-value analytical operation that complements grouping and summarization and is a natural next transformation for tabular data.

Suggested success criteria:

- Support index columns, pivot columns, value columns, and at least the `Sum`, `Count`, `Average`, `Min`, and `Max` aggregates.
- Define predictable output-column naming and ordering, including multiple value or pivot columns.
- Define behavior for missing combinations, null values, duplicate keys, and empty inputs.
- Include runnable examples and Pester coverage for common and edge-case shapes.

## 3. Add time-aware summary conveniences

Allow users to summarize by month or year directly from a DateTime column without manually adding helper columns.

Rationale: Time-based reporting is common in real data workflows, and removing repetitive calculated-column boilerplate makes the pipeline easier to read and less error-prone.

Suggested success criteria:

- Support explicit, discoverable syntax for date parts such as year, quarter, month, and day.
- Preserve chronological ordering and make the grouping key/value representation clear.
- Define behavior for DateTime, DateTimeOffset, null, and invalid or mixed date values.
- Demonstrate grouped time summaries in a self-contained example with regression tests.

## 4. Add data-quality checks after profiling

Add checks that flag missing values, duplicate keys, mixed types, and suspicious values after `Describe`.

Rationale: Profiling should lead naturally to actionable quality findings, helping users decide what to clean before analysis or export.

Suggested success criteria:

- Provide a pipeline-friendly quality-check command or companion to the profile result.
- Report stable, machine-readable findings with column/key, check type, severity, count, and useful sample details.
- Cover missingness thresholds, duplicate-key detection, mixed-type columns, and configurable suspicious-value rules.
- Make thresholds and policies explicit, avoid silently coercing data, and include runnable examples and Pester coverage.
