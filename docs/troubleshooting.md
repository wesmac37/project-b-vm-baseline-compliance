# Troubleshooting

## "Import-Module: The specified module ... was not loaded"

**Symptom:** Running any script fails with an error resolving
`VmBaselineToolkit.psd1`.

**Cause:** You are running a script from outside the repository, or the repository
was copied without preserving the relative folder structure between `scripts/` and
`src/VmBaselineToolkit/`.

**Fix:** Run scripts from the repository root (or anywhere, since scripts resolve
paths via `$PSScriptRoot`), but make sure the `src/VmBaselineToolkit/` folder is
still two levels up from `scripts/`. Do not move `scripts/*.ps1` to a different
directory depth without updating the `$repoRoot` resolution line at the top of the
script.

## "Get-VmBaselineTarget: sample data file not found"

**Symptom:** `-SimulationMode` fails to find `sample-vm-inventory.json`.

**Cause:** The `sample-data/` directory was not copied alongside the rest of the repo,
or `-SampleDataPath` was passed with an incorrect path.

**Fix:** Confirm `sample-data/sample-vm-inventory.json` exists relative to the repo
root. If calling `Get-VmBaselineTarget` directly (not via the script), pass an
explicit `-SampleDataPath` if your working directory differs from the repo root.

## "Get-VmBaselineTarget: the Az.Compute module (Get-AzVM) is not available"

**Symptom:** Live mode (`-SimulationMode:$false`) fails immediately.

**Cause:** The `Az` PowerShell module is not installed.

**Fix:** `Install-Module -Name Az -Scope CurrentUser -Force`, then `Connect-AzAccount`.
Or just use `-SimulationMode` (the default) — no Az module or credentials are needed.

## Audit script exits with code 1 and I didn't expect a failure

**This is very likely correct behavior, not a bug.** Exit code `1` means at least one
High-severity rule (`NsgAssociation`, `BackupPosture`, or `IdentitySettings`) is in a
`Fail` state. In the shipped sample data, `vm-app02-prod` is intentionally
non-compliant on multiple High-severity rules to demonstrate this exact behavior —
see `sample-data/sample-vm-inventory.json`'s `IntentionalFailureNote` field on that
VM. Open the generated `sample-compliance-report.md` to see exactly which rule(s)
failed and why. Exit code `2` (not `1`) indicates an actual unhandled script error.

## PSScriptAnalyzer reports style warnings

**Symptom:** CI or local `Invoke-ScriptAnalyzer` output shows `Warning`-severity
findings (e.g. `PSAvoidUsingWriteHost`, `PSUseShouldProcessForStateChangingFunctions`).

**Cause:** Some console-facing UX code intentionally uses `Write-Host` for colored,
human-readable summaries. The CI workflow only fails the build on `Error`-severity
findings, matching common enterprise PSScriptAnalyzer gating practice.

**Fix:** No action needed for `Warning`-level findings unless your organization's
policy is stricter — adjust the `-Severity` filter in
`.github/workflows/powershell-ci.yml` if you want to fail on warnings too.

## Pester tests fail with "Cannot bind argument to parameter 'VM' because it is null"

**Cause:** A rule function was called without a VM object, usually because a test's
`BeforeAll` block did not run (e.g. tests were invoked with `-SkipRun` or a filter
that excluded the `BeforeAll` scope in an older Pester version).

**Fix:** Confirm Pester 5.0+ is installed (`Get-Module -ListAvailable Pester`) and run
the whole `Describe` block rather than filtering to a single `It` when debugging
scope issues.

## Markdown report tables look misaligned in a plain text editor

**Cause:** Markdown tables are meant to be rendered by a Markdown viewer (GitHub,
VS Code preview, etc.), not read as raw fixed-width text.

**Fix:** View `sample-compliance-report.md` in a Markdown renderer, or open the
companion `sample-compliance-report.csv` in a spreadsheet application for a plain
tabular view.

## Live NSG/Backup/Monitoring checks always show "tag-based intent" disclaimers

**Cause:** Either you are running in `-SimulationMode` (expected — there is no live
Azure API to query), or your account/identity does not have permission to query
Recovery Services vaults / VM extensions in live mode.

**Fix:** In live mode, ensure the identity has at least Reader role on the relevant
Recovery Services vault and Microsoft.Compute resources. This disclaimer is by
design per the baseline specification — it is not a bug, it is a transparency
feature so reports never silently overstate verification confidence.
