import 'package:drift/native.dart';

/// How long a connection waits for another connection's lock before failing
/// with `SQLITE_BUSY` ("database is locked").
const int sqliteBusyTimeoutMs = 5000;

/// Shared `setup:` callback for every file-backed SQLite connection.
///
/// - `busy_timeout` makes a writer wait for a lock held by another connection
///   (for example the widget background isolate) instead of failing at once.
///   It is set first so the journal-mode switch below also waits for locks.
/// - `journal_mode=WAL` lets readers keep reading committed data while another
///   connection holds a write transaction.
///
/// Drift runs this on the connection's own isolate before any other statement,
/// so it is a top-level value that captures nothing and can be sent across
/// isolates. It is typed through drift's [DatabaseSetup] because `sqlite3`
/// (which defines the `Database` parameter type) is not a direct dependency.
// ignore: prefer_function_declarations_over_variables
final DatabaseSetup configureSqliteConnection = (database) {
  database.execute('PRAGMA busy_timeout = $sqliteBusyTimeoutMs');
  database.execute('PRAGMA journal_mode = WAL');
};
