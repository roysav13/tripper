import 'package:drift/drift.dart';

import '../../features/expenses/data/expense_tables.dart';
import '../../features/expenses/data/expenses_dao.dart';
import '../../features/itinerary/data/itinerary_tables.dart';
import '../../features/journal/data/journal_dao.dart';
import '../../features/journal/data/journal_tables.dart';
import '../../features/places/data/place_tables.dart';
import '../../features/places/data/places_dao.dart';
import '../../features/trips/data/trip_tables.dart';
import '../../features/trips/data/trips_dao.dart';
import '../../features/vault/data/document_tables.dart';
import '../../features/vault/data/documents_dao.dart';

part 'app_database.g.dart';

/// Schema history:
///   v1 — empty scaffold (M0)
///   v2 — Trips + TripDestinations (M1)
///   v3 — trip dates nullable: planned + open-ended trips (M1 polish)
///   v4 — Documents + TripDocuments (M2)
///   v5 — Places (M3)
///   v6 — Trips.completionPromptShown (M3c)
///   v7 — Expenses (M5.5)
///   v8 — Expenses conversion columns (M5.5b)
///   v9 — ItineraryItems (M5.7, feature since withdrawn — see below)
///   v10 — JournalEntries + JournalPhotos (Journal feature)
///
/// ItineraryItems has no DAO and nothing reads or writes it: the Plan
/// feature was withdrawn on 2026-07-26 as "currently won't do"
/// (`docs/adr/ADR-001-itinerary-redesign.md`). The table is kept rather
/// than dropped so no installed app has to run a destructive migration,
/// and so any rows already on a device survive if the feature comes
/// back. Do not remove it without a v10 migration and a migration test.
@DriftDatabase(
  tables: [
    Trips,
    TripDestinations,
    Documents,
    TripDocuments,
    Places,
    Expenses,
    ItineraryItems,
    JournalEntries,
    JournalPhotos,
  ],
  daos: [TripsDao, DocumentsDao, PlacesDao, ExpensesDao, JournalDao],
)
class AppDatabase extends _$AppDatabase {
  /// Executor is injected so tests can pass NativeDatabase.memory().
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        // IMPORTANT: `createTable` always builds the table at its CURRENT
        // definition, not the definition as of that schema version. So a
        // create step is mutually exclusive with every later `addColumn`
        // on the same table — `else if`, never a second `if`. Getting
        // this wrong crashes on open ("duplicate column name") for
        // anyone upgrading across two or more versions at once, while
        // single-step upgrades and fresh installs look fine.
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(trips);
            await m.createTable(tripDestinations);
          } else {
            if (from == 2) {
              // Relax NOT NULL on dates — table recreation, data kept.
              await m.alterTable(TableMigration(trips));
            }
            if (from < 6) {
              await m.addColumn(trips, trips.completionPromptShown);
            }
          }
          if (from < 4) {
            await m.createTable(documents);
            await m.createTable(tripDocuments);
          }
          if (from < 5) {
            await m.createTable(places);
          }
          if (from < 7) {
            // Created at the current definition — conversion columns
            // included, so the v8 step below must not also run.
            await m.createTable(expenses);
          } else if (from < 8) {
            await m.addColumn(expenses, expenses.convertedAmountMinor);
            await m.addColumn(expenses, expenses.convertedCurrency);
            await m.addColumn(expenses, expenses.convertedRateAt);
          }
          if (from < 9) {
            await m.createTable(itineraryItems);
          }
          if (from < 10) {
            await m.createTable(journalEntries);
            await m.createTable(journalPhotos);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
