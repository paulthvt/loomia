---
inclusion: fileMatch
fileMatchPattern: ["test/**", "supabase/tests/**"]
---

# Tests

- `test/` mirrors `lib/`. Widget test per screen, plain Dart unit test per
  domain rule. Override providers to fake I/O; there are no mocking packages.
- Database rules and RLS are pinned by pgTAP tests in `supabase/tests/`.
- Goldens: `test/previews_test.dart` renders every `@Preview` against
  `test/goldens/`, compared on Linux only. Never commit a golden generated
  locally. After a visual change, push the branch and regenerate through CI:

```bash
gh workflow run CI --ref <branch> -f update-goldens=true
gh run list --workflow CI --branch <branch> --event workflow_dispatch --limit 1
gh run watch <run-id>
rm test/goldens/*.png
gh run download <run-id> -n goldens -D test/goldens
```

  Open the PNGs before committing: an update accepts whatever renders.
