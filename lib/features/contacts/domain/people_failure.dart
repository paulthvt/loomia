/// Everything a people call can fail with. Screens react to exactly these two,
/// as they do to `AuthFailure`.
enum PeopleFailure implements Exception { network, unknown }

/// An undo the server refused because the person changed since the tick
/// (#372): not a failure to report, nothing was changed.
class UndoStale implements Exception {
  const UndoStale();
}
