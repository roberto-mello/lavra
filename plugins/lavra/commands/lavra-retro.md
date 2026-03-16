---
name: lavra-retro
description: Weekly retrospective with shipping analytics, team performance, and knowledge synthesis
argument-hint: "[--window 14d] [--since 2026-03-01]"
---

<objective>
Run a retrospective that analyzes what shipped, how the team performed, and what patterns emerged. Synthesizes knowledge.jsonl entries to surface recurring themes, compound learning, and knowledge gaps. Outputs a markdown report and saves a snapshot for trend tracking.
</objective>

<execution_context>
<input_document> #$ARGUMENTS </input_document>
</execution_context>

<process>

### Phase 1: Time Window

1. **Determine the retrospective window**

   Parse arguments for time range:
   - Default: last 7 days
   - `--window Nd` sets the window to N days back from today
   - `--since YYYY-MM-DD` sets an explicit start date

   ```bash
   # Calculate the since date
   if [ -n "$SINCE" ]; then
     since_date="$SINCE"
   elif [ -n "$WINDOW" ]; then
     days="${WINDOW%d}"
     since_date=$(date -v-${days}d +%Y-%m-%d 2>/dev/null || date -d "${days} days ago" +%Y-%m-%d)
   else
     since_date=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d "7 days ago" +%Y-%m-%d)
   fi
   until_date=$(date +%Y-%m-%d)
   ```

2. **Load previous retro snapshot** (for trend comparison)

   ```bash
   # Find the most recent previous retro
   ls -1 .beads/retros/*.json 2>/dev/null | sort | tail -1
   ```

   If a previous snapshot exists, load it. This enables velocity trend comparison and topic drift analysis in later phases.

### Phase 2: Shipping Analysis

Analyze git history within the window.

1. **Identify the current user**

   ```bash
   git config user.email
   git config user.name
   ```

   Use this to distinguish "You" from teammates in all output.

2. **Commit breakdown**

   ```bash
   git log --since="$since_date" --until="$until_date" --format="%H|%an|%ae|%s" --no-merges
   ```

   From this data, compute:
   - Total commits by author
   - Commit type breakdown using conventional commit prefixes (feat/fix/refactor/test/chore/docs)
   - Commits that don't follow conventional format (flag as "untyped")

3. **Diff statistics**

   ```bash
   git log --since="$since_date" --until="$until_date" --shortstat --no-merges --format=""
   ```

   Aggregate: files changed, lines added, lines removed.

4. **Hotspot files** (most frequently changed)

   ```bash
   git log --since="$since_date" --until="$until_date" --name-only --no-merges --format="" | sort | uniq -c | sort -rn | head -10
   ```

5. **PR activity**

   ```bash
   gh pr list --state merged --search "merged:>=$since_date" --json number,title,author,mergedAt,additions,deletions
   gh pr list --state open --json number,title,author,createdAt
   ```

   Compute: PRs merged, PRs still open, merge rate.

### Phase 3: Beads Analysis

Analyze bead activity within the window.

1. **Bead throughput**

   ```bash
   bd list --json
   ```

   From the JSON output, filter by timestamps within the window:
   - Beads created in the window
   - Beads closed in the window
   - Beads still open/in-progress

2. **Cycle time**

   For beads closed in the window, calculate the time from creation to closure. Report:
   - Average cycle time
   - Fastest and slowest beads (with IDs and titles)

3. **Blocked beads**

   ```bash
   bd list --status=blocked --json 2>/dev/null || true
   ```

   List blocked beads with their blocking reasons. If `bd` does not support `--status=blocked`, scan bead descriptions and comments for blocking language.

4. **Epic progress**

   ```bash
   bd list --type=epic --json 2>/dev/null || true
   ```

   For each epic, count children by status and report percentage complete.

### Phase 4: Work Patterns

Analyze temporal patterns from git timestamps.

1. **Session detection**

   Parse commit timestamps and group into sessions using a 45-minute gap threshold. A session is a contiguous block of commits where no two adjacent commits are more than 45 minutes apart.

   Classify sessions:
   - **Deep work**: 3+ commits spanning 60+ minutes
   - **Quick fix**: 1-2 commits spanning less than 30 minutes
   - **Standard**: everything else

   Report: number of sessions by type, average session length.

2. **Peak hours**

   ```bash
   git log --since="$since_date" --until="$until_date" --format="%H" --no-merges | sort | uniq -c | sort -rn | head -5
   ```

   Report the top 5 most active hours.

3. **Velocity trend**

   If a previous retro snapshot exists, compare:
   - Commits this period vs last period
   - Beads closed this period vs last period
   - Knowledge entries this period vs last period

   Express as percentage change with direction indicator.

### Phase 5: Team Breakdown

For each contributor in the window (skip this section entirely for solo projects with only one author):

1. **What they shipped**

   List their specific commits grouped by type. Use actual commit messages, not generic summaries. Limit to the 10 most significant commits per person (prioritize feat > fix > refactor > others).

2. **Strengths demonstrated**

   Anchor observations in actual work:
   - "Shipped 3 security fixes across auth and payments" (not "Good at security")
   - "Refactored the billing pipeline from 400 to 180 lines" (not "Writes clean code")

   Only make claims that are directly supported by the commit data.

3. **Growth opportunities**

   Be specific, constructive, and kind:
   - "12 of 15 commits lack conventional prefixes -- adopting them would make changelogs easier" (not "Needs better commit messages")
   - "No test commits this week -- consider pairing tests with the 3 new features" (not "Doesn't write tests")

   Frame as opportunities, not criticisms. If there is nothing constructive to say, skip this subsection.

4. **AI-assisted work**

   Count commits with `Co-Authored-By` trailers containing AI indicators (Claude, Copilot, GPT, etc.). Report as a percentage of their total commits.

### Phase 6: Knowledge Synthesis

This is the lavra differentiator. Read and analyze the knowledge base.

1. **Load knowledge entries from the window**

   ```bash
   # Read knowledge.jsonl and filter by timestamp
   cat .beads/memory/knowledge.jsonl | while IFS= read -r line; do
     ts=$(echo "$line" | jq -r '.ts')
     if [ "$ts" -ge "$(date -j -f '%Y-%m-%d' "$since_date" +%s 2>/dev/null || date -d "$since_date" +%s)" ]; then
       echo "$line"
     fi
   done
   ```

   Alternatively, read the entire file and filter in your analysis.

2. **Tag frequency analysis**

   Group entries by tags. Report the top 10 most frequent tags with counts. These represent the topics the team engaged with most heavily.

3. **Type breakdown**

   Count entries by type (LEARNED, DECISION, FACT, PATTERN, INVESTIGATION). A healthy distribution has all types represented. Flag if any type is absent.

4. **Recurring patterns**

   Identify clusters: topics that appear 3+ times in the window. For each cluster:
   - Summarize the theme
   - List the specific entries
   - Assess whether this is a systemic issue or normal domain complexity

   For genuine recurring issues (same problem hit multiple times), create a new PATTERN entry:

   ```bash
   bd comments add {RELEVANT_BEAD_ID} "PATTERN: Recurring theme from retro -- {description of the pattern and its frequency}"
   ```

   If no relevant bead exists, log it directly:

   ```bash
   echo '{"key":"pattern-retro-{slug}","type":"pattern","content":"{description}","source":"retro","tags":[{tags}],"ts":'$(date +%s)'}' >> .beads/memory/knowledge.jsonl
   ```

5. **Knowledge gaps**

   Cross-reference: for each hotspot file (Phase 2) and each closed bead (Phase 3), check whether any knowledge entries reference them. Files or beads with significant activity but zero knowledge entries represent gaps.

   Report these gaps with a recommendation: "Consider running /lavra-compound on {bead} to capture what was learned."

6. **Trend comparison**

   If a previous retro snapshot exists, compare:
   - Top tags this period vs last period
   - New topics that appeared
   - Topics that disappeared (potentially resolved)
   - "Last week's top concern was X, this week it's Y"

### Phase 7: Output

1. **Generate markdown report**

   Structure the report with these sections:

   ```markdown
   # Retrospective: {since_date} to {until_date}

   ## Summary
   This week: N features shipped, M bugs fixed, K knowledge entries captured.
   Top pattern: {most frequent recurring theme}.
   Velocity: {up/down/stable} vs previous period.

   ## Shipping
   {Commit breakdown table}
   {Hotspot files}
   {PR activity}

   ## Beads
   {Throughput: created vs closed}
   {Cycle time stats}
   {Blocked beads}
   {Epic progress}

   ## Work Patterns
   {Session analysis}
   {Peak hours}
   {Velocity trend}

   ## Team
   {Per-contributor breakdown -- omit for solo projects}

   ## Knowledge
   {Tag frequency}
   {Type breakdown}
   {Recurring patterns}
   {Knowledge gaps}
   {Trend comparison}

   ## Action Items
   {Synthesized from all sections: what to do differently next week}
   ```

   Output the report to the user.

2. **Save snapshot**

   ```bash
   mkdir -p .beads/retros
   ```

   Save a JSON snapshot to `.beads/retros/{until_date}.json` containing:

   ```json
   {
     "date": "{until_date}",
     "window": { "since": "{since_date}", "until": "{until_date}" },
     "shipping": {
       "total_commits": N,
       "by_type": { "feat": N, "fix": N, "refactor": N, "test": N, "chore": N, "docs": N },
       "files_changed": N,
       "lines_added": N,
       "lines_removed": N,
       "prs_merged": N,
       "hotspot_files": ["file1", "file2"]
     },
     "beads": {
       "created": N,
       "closed": N,
       "avg_cycle_time_hours": N,
       "blocked": N
     },
     "patterns": {
       "sessions": { "deep_work": N, "quick_fix": N, "standard": N },
       "peak_hours": [H1, H2, H3]
     },
     "knowledge": {
       "total_entries": N,
       "by_type": { "learned": N, "decision": N, "fact": N, "pattern": N, "investigation": N },
       "top_tags": ["tag1", "tag2", "tag3"],
       "recurring_themes": ["theme1", "theme2"],
       "gaps": ["file_or_bead_with_no_knowledge"]
     }
   }
   ```

3. **Final summary**

   Print a one-line summary: "Retro saved to .beads/retros/{until_date}.json. {N} action items identified."

</process>

<success_criteria>
- [ ] Time window correctly parsed (default 7d, or from arguments)
- [ ] Git history analyzed with commit type breakdown
- [ ] Bead throughput and cycle time calculated
- [ ] Work patterns detected (sessions, peak hours)
- [ ] Team breakdown shows specific, anchored observations (or skipped for solo projects)
- [ ] Knowledge.jsonl entries analyzed for tag frequency and recurring themes
- [ ] Knowledge gaps identified (active areas with no captured knowledge)
- [ ] Snapshot saved to .beads/retros/ for future trend comparison
- [ ] Markdown report output with all sections
</success_criteria>

<guardrails>

### Praise is Specific

Never write generic praise like "Great work this week." Every positive observation must reference a specific commit, PR, or metric. "Shipped the OAuth migration (12 files, 3 PRs) with zero rollbacks" is praise. "Did a good job" is noise.

### Growth Feedback is Constructive

Frame growth areas as opportunities with clear next steps. Never criticize. "No test commits alongside the 4 new endpoints -- consider adding integration tests next week" gives actionable direction without judgment.

### Identify "You" Correctly

Use `git config user.email` to determine the current user. Label their work as "You" in the report. Do not guess or assume based on common names.

### Handle Solo Projects Gracefully

If all commits in the window belong to a single author, skip the Team Breakdown section entirely. Do not generate a team section with one person.

### Knowledge Synthesis is the Priority

The shipping and pattern analysis is table stakes. The real value is in Phase 6: surfacing recurring themes, identifying knowledge gaps, and creating PATTERN entries for systemic issues. Spend the most analytical effort here.

### Snapshots Enable Trends

Always save the snapshot, even for the first retro. Future retros depend on having historical data for comparison. The snapshot format must remain stable across versions.

</guardrails>
