# Research paper

`CSGO_xD_Research_Paper.docx` is the completed manuscript. It follows the retained reference's A4 geometry, Times New Roman typography, author block, Roman and letter headings, table styling and page-number footer. It contains 16 pages, nine tables and eight figures, including Dust2 comparisons of all 12 implemented learners.

The paper reports the production run: 10,279,321 retained events, a bounded 59,763-event sample and 8,000 held-out test events from 32 matches. It explicitly distinguishes conditional expected damage from expected kills and reports the lack of statistically established improvement over the weapon-hitbox baseline.

## Rebuild from the committed snapshot

Use Python 3 with `python-docx` and `Pillow` installed. From the repository root:

```sh
python paper/build_paper.py --results results
```

This uses the retained reference, measured tables under `results/`, descriptive inputs under `paper/inputs/` and compact map panels under `paper/figures/panels/`. It does not require the raw archive or fitted models. The builder checks the reference hash, rejects smoke results and preserves the reference's non-content document parts. The reference is an earlier draft, not the final measured manuscript.

## Rebuild after running the analysis

First run the full production workflow as described in the root README. In R, from the project root:

```r
source("paper/export_paper_stats.R")
source("paper/render_paper_maps.R")
```

Then:

```sh
python paper/build_paper.py --results output
```

The R helpers require locally regenerated model caches and the archive's radar calibration. They export descriptive summaries and draw manuscript panels at their intended physical print size; they do not refit the models. The builder reads numerical results rather than filling in assumed metrics.

The current manuscript was rendered through Word and every final page was visually reviewed. After rebuilding, review pagination, equation typography, table splits and figure legends in Word or LibreOffice before submission. Changes in fonts or rendering software can alter pagination.
