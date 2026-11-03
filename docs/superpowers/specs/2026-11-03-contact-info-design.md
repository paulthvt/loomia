# Contact Info section — design

Issue [#430](https://github.com/paulthvt/loomia/issues/430). No new UI pattern:
the section, its FactRows and the edit form are reused as they are.

## Intent

The facts section of a person reads as a profile, not a questionnaire. Its
header and labels follow the words distributors use, and a free Bio comes
first, for every stage (prospect, customer, team).

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| Section name | "Info" (FR "Infos"), was "What you know" | The issue's wording; short header. |
| Needs | "Concerns" (FR "Problématiques") | The issue's wording. |
| Uses | "Favourite products" (FR "Produits préférés") | The issue's wording. |
| Job and Bio | The job field becomes Bio, first in the section, multiline, hint "Age, children, work…" | The issue removes the job and puts it in the Bio. |
| Where Bio is stored | The existing `profession` column; only the Dart field is renamed `bio` | No migration: the released app keeps reading and writing the same text, and an existing job reads as a one-line bio. |
| French copy | Old keys renamed and removed from `app_fr.arb`; Weblate fills them | Same as #418. French shows English until the next Weblate PR. |
| Row subtitle | Bio's first line, else concerns | Was job, else needs; the row shows one line. |
