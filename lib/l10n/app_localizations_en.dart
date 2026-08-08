// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tripper';

  @override
  String get tabTrips => 'Trips';

  @override
  String get tabVault => 'Vault';

  @override
  String get tabPlaces => 'Places';

  @override
  String get tripsEmptyTitle => 'Plan your first trip';

  @override
  String get tripsEmptyBody =>
      'Dates, documents, and places — all in one pocket.';

  @override
  String get tripsEmptyCta => 'Create trip';

  @override
  String get backupReminderBody =>
      'Your trips live only on this device. Back them up so a lost phone doesn\'t mean a lost trip.';

  @override
  String get backupReminderCta => 'Back up now';

  @override
  String get errorStateTitle => 'Something went wrong loading this';

  @override
  String get errorStateBody =>
      'Your data is still safe on this device. Try again.';

  @override
  String get errorStateRetry => 'Retry';

  @override
  String get vaultEmptyTitle => 'Your documents, ready anywhere';

  @override
  String get vaultEmptyBody =>
      'Passport, tickets, bookings — stored only on this device.';

  @override
  String get vaultEmptyCta => 'Add document';

  @override
  String get placesEmptyTitle => 'Where to next?';

  @override
  String get placesEmptyBody =>
      'Keep a list of places you want to see, and the ones you already have.';

  @override
  String get placesEmptyCta => 'Add place';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get sectionActive => 'Active now';

  @override
  String get sectionUpcoming => 'Upcoming';

  @override
  String get sectionPlanned => 'Planned';

  @override
  String get sectionPast => 'Past';

  @override
  String get sectionArchived => 'Archived';

  @override
  String get datesTbd => 'Dates TBD';

  @override
  String fromDate(String date) {
    return 'From $date';
  }

  @override
  String tripDayOpen(int n) {
    return 'Day $n';
  }

  @override
  String get themeToggleTooltip => 'Switch theme';

  @override
  String tripDayCount(int n, int m) {
    return 'Day $n of $m';
  }

  @override
  String get tripFormTitleNew => 'New trip';

  @override
  String get tripFormTitleEdit => 'Edit trip';

  @override
  String get tripFormName => 'Trip name';

  @override
  String get tripFormDestinations => 'Destinations';

  @override
  String get tripFormAddDestination => 'Add destination';

  @override
  String get tripFormAddDestinationHint => 'Krabi';

  @override
  String get tripFormDates => 'Dates';

  @override
  String get tripFormDatesHint =>
      'Optional — leave empty while planning, or set only a start for one-way trips.';

  @override
  String get tripFormStartDate => 'Start date';

  @override
  String get tripFormEndDate => 'End date';

  @override
  String get errEndWithoutStart => 'Set a start date first';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get errNameRequired => 'Give the trip a name';

  @override
  String get errNoDestination => 'Add at least one destination';

  @override
  String get errDatesRequired => 'Pick valid start and end dates';

  @override
  String get menuEdit => 'Edit';

  @override
  String get menuArchive => 'Archive';

  @override
  String get menuUnarchive => 'Unarchive';

  @override
  String get menuDelete => 'Delete';

  @override
  String get deleteTripTitle => 'Delete this trip?';

  @override
  String get deleteTripBody =>
      'The trip is removed. Documents and places linked to it are kept.';

  @override
  String get tabDocuments => 'Documents';

  @override
  String get tabPlacesInTrip => 'Places';

  @override
  String get tabExpenses => 'Spend';

  @override
  String get expensesEmptyTitle => 'Track what this trip costs';

  @override
  String get expensesEmptyBody =>
      'Add what you spend as you go — the total and a category breakdown build up here.';

  @override
  String get expensesEmptyCta => 'Add an expense';

  @override
  String get expensesTotal => 'Total';

  @override
  String expensesConvertedTotal(String amount, String currency) {
    return '≈ $amount $currency';
  }

  @override
  String expensesConversionPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expenses not converted yet',
      one: '1 expense not converted yet',
    );
    return '$_temp0';
  }

  @override
  String get expensesConversionOffHint =>
      'Set a home currency in Settings to see one combined total.';

  @override
  String expensesRatesAsOf(String date) {
    return 'Rates from $date';
  }

  @override
  String get settingsHomeCurrency => 'Home currency';

  @override
  String get settingsHomeCurrencyHint =>
      'Converts mixed-currency trip totals into one figure. Needs a connection the first time; converted amounts are then stored and work offline. Leave empty to just list each currency.';

  @override
  String get settingsHomeCurrencyOff => 'Off';

  @override
  String get currencyPickerSearch => 'Search currency';

  @override
  String get currencyPickerOffHint =>
      'Show each currency separately, no conversion.';

  @override
  String get currencyPickerNoMatch => 'No currency matches that.';

  @override
  String get expenseFormTitle => 'Add expense';

  @override
  String get expenseFormEditTitle => 'Edit expense';

  @override
  String get expenseFormAmount => 'Amount';

  @override
  String get expenseFormCurrency => 'Currency';

  @override
  String get expenseFormNotes => 'Note (optional)';

  @override
  String get expenseFormDate => 'Date';

  @override
  String get errAmountRequired => 'Enter an amount like 12.30';

  @override
  String get errCurrencyRequired => 'Use a 3-letter code, e.g. ILS';

  @override
  String get expenseDeleted => 'Expense deleted.';

  @override
  String get catFood => 'Food';

  @override
  String get catActivities => 'Activities';

  @override
  String get catShopping => 'Shopping';

  @override
  String get tripDocsEmptyTitle => 'No documents linked';

  @override
  String get tripDocsEmptyBody =>
      'Flights, stays, and tickets for this trip will live here.';

  @override
  String get vaultPinnedSection => 'Pinned · quick access';

  @override
  String get vaultAllSection => 'All documents';

  @override
  String get catPassport => 'Passport / ID';

  @override
  String get catVisa => 'Visa';

  @override
  String get catFlight => 'Flight';

  @override
  String get catStay => 'Stay';

  @override
  String get catInsurance => 'Insurance';

  @override
  String get catTransport => 'Transport';

  @override
  String get catOther => 'Other';

  @override
  String get manualRecord => 'Manual';

  @override
  String expiryShort(String date) {
    return 'Exp $date';
  }

  @override
  String get docFormTitle => 'Add document';

  @override
  String get docFormName => 'Document name';

  @override
  String get docFormAttachFile => 'Attach file';

  @override
  String get docFormExpiry => 'Expiry date';

  @override
  String get docFormGlobal => 'Keep in global vault';

  @override
  String get docFormGlobalHint =>
      'For documents that outlive trips — passport, license, insurance.';

  @override
  String get fieldFlightNumber => 'Flight number';

  @override
  String get fieldConfirmationCode => 'Confirmation code';

  @override
  String get docFormDepartureTime => 'Departure time';

  @override
  String get docFormDepartureTimeHint =>
      'Powers the check-in-opens reminder (M5.3) — optional.';

  @override
  String get docOcrPrefilled =>
      'Filled in from the photo — double-check before saving.';

  @override
  String docTitleFlight(String number) {
    return 'Flight $number';
  }

  @override
  String get fieldBookingRef => 'Booking reference';

  @override
  String get fieldDocumentNumber => 'Document number';

  @override
  String get docActionOpen => 'Open';

  @override
  String get showCodeAction => 'Show at gate';

  @override
  String get showCodeFileMissing =>
      'This document\'s file is missing. Re-attach it from the vault.';

  @override
  String get showCodePdfFallback =>
      'Couldn\'t display this PDF here. Open it in a viewer instead.';

  @override
  String get docActionPin => 'Pin for quick access';

  @override
  String get docActionUnpin => 'Unpin';

  @override
  String get docActionLink => 'Link to trips';

  @override
  String get pinLimitReached =>
      'Up to 4 documents can be pinned. Unpin one first.';

  @override
  String get noTripsToLink => 'No trips yet — create one first.';

  @override
  String get docLinksUpdated => 'Trip links updated.';

  @override
  String get docLinksUpdateFailed => 'Couldn\'t update trip links. Try again.';

  @override
  String get vaultLockedTitle => 'Vault locked';

  @override
  String get vaultLockedBody =>
      'Your documents are protected by your device lock.';

  @override
  String get unlockCta => 'Unlock';

  @override
  String get unlockReason => 'Unlock your document vault';

  @override
  String get unlockSettingsReason => 'Unlock Tripper settings';

  @override
  String get settingsLockedTitle => 'Settings locked';

  @override
  String get settingsLockedBody =>
      'Backup and security options are protected by your device lock.';

  @override
  String get deleteDocTitle => 'Delete this document?';

  @override
  String get deleteDocBody =>
      'The document and its file are removed from this device.';

  @override
  String expiryTripWarning(String title) {
    return '$title expires too close to this trip\'s end. Check entry requirements.';
  }

  @override
  String get tripPlacesEmptyTitle => 'No places yet';

  @override
  String get tripPlacesEmptyBody => 'Track what you want to see on this trip.';

  @override
  String get placesWantSection => 'Want to go';

  @override
  String get placesBeenSection => 'Been there';

  @override
  String get placeMarkVisited => 'Mark as visited';

  @override
  String get placeViewOnMap => 'View on map';

  @override
  String get placeUnvisit => 'Move back to wishlist';

  @override
  String visitedOn(String date) {
    return 'Visited $date';
  }

  @override
  String get statsCountries => 'Countries';

  @override
  String get statsPlacesVisited => 'Places visited';

  @override
  String get statsDaysTraveled => 'Days away';

  @override
  String get placeFormTitle => 'Add place';

  @override
  String get placeFormName => 'Place name';

  @override
  String get placeFormCity => 'City';

  @override
  String get placeFormCountry => 'Country';

  @override
  String get placeFormTrip => 'Link to a trip';

  @override
  String get mapViewToggle => 'Map view';

  @override
  String get listViewToggle => 'List view';

  @override
  String get pickOnMap => 'Pick on map';

  @override
  String get pickOnMapTitle => 'Drop a pin';

  @override
  String get pickOnMapHint =>
      'Search above, or long-press the map to place the pin';

  @override
  String get mapSearchHint => 'Search for a place';

  @override
  String get mapSearchNoResults => 'No results — try a different spelling.';

  @override
  String get mapSearchOffline =>
      'Search needs a connection. Long-press the map instead.';

  @override
  String get mapLayersButton => 'Map layers';

  @override
  String get mapLayerNormal => 'Default';

  @override
  String get mapLayerSatellite => 'Satellite';

  @override
  String get mapLayerTerrain => 'Terrain';

  @override
  String addWithoutLocation(String query) {
    return 'Add \"$query\" without a location';
  }

  @override
  String get noLocationChip => 'No location';

  @override
  String get editPlaceTitle => 'Edit place';

  @override
  String get deletePlaceTitle => 'Delete this place?';

  @override
  String get deletePlaceBody =>
      'The place is removed from your lists and the map.';

  @override
  String get tripCompleteTitle => 'Trip finished — update your map?';

  @override
  String tripCompleteBody(String trip) {
    return '$trip is over. Mark the places you got to as visited:';
  }

  @override
  String get tripCompleteConfirm => 'Mark visited';

  @override
  String get tripCompleteSkip => 'Not now';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get settingsSecurity => 'Security';

  @override
  String get settingsVaultLock => 'Lock the vault';

  @override
  String get settingsVaultLockHint =>
      'Ask for your fingerprint before opening documents.';

  @override
  String get settingsBackup => 'Backup';

  @override
  String get settingsBackupHint =>
      'Everything lives on this device only. Export a backup you can restore after a reinstall or on a new phone.';

  @override
  String get settingsExport => 'Export backup';

  @override
  String get settingsExportShareText => 'Tripper backup';

  @override
  String get settingsExportFailed => 'Couldn\'t create the backup. Try again.';

  @override
  String get settingsImport => 'Restore backup';

  @override
  String get settingsImportTitle => 'Restore from a backup?';

  @override
  String get settingsImportWarning =>
      'This replaces every trip, document, and place on this device with the backup\'s contents.';

  @override
  String get settingsImportDone =>
      'Backup restored. Restart Tripper to see it.';

  @override
  String get settingsImportCorrupt =>
      'That file isn\'t a valid Tripper backup.';

  @override
  String get settingsImportTooNew =>
      'That backup came from a newer version of Tripper.';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsExpiryNoticeHint =>
      'How far ahead of a document\'s expiry date counts as coming up.';

  @override
  String get settingsExpiryNoticeOff => 'Off';

  @override
  String docExpiryNotificationTitle(String title) {
    return '$title expires soon';
  }

  @override
  String docExpiryNotificationBody(String date) {
    return 'Expires $date.';
  }

  @override
  String tripCountdownNotificationTitle(String name) {
    return '$name starts soon';
  }

  @override
  String tripCountdownNotificationBodyClear(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Starts in $days days',
      one: 'Starts in 1 day',
    );
    return '$_temp0 — everything\'s in order.';
  }

  @override
  String tripCountdownNotificationBodyWithIssues(int days, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Starts in $days days',
      one: 'Starts in 1 day',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents need',
      one: '1 document needs',
    );
    return '$_temp0 — $_temp1 attention.';
  }

  @override
  String checkInNotificationTitle(String title) {
    return 'Check-in opens for $title';
  }

  @override
  String get checkInNotificationBody =>
      'Check-in usually opens 24 hours before departure. Airlines vary this 24–48h, so double-check with yours.';

  @override
  String get placeFormNoTrip => 'No trip';

  @override
  String tripPlacesProgress(int visited, int total) {
    return '$visited of $total visited';
  }

  @override
  String get tabJournal => 'Journal';

  @override
  String get journalEmptyTitle => 'No journal entries yet';

  @override
  String get journalEmptyBody =>
      'Log a note from the road — where you went and what happened.';

  @override
  String get journalAddEntryCta => 'Add entry';

  @override
  String get journalEntryFormTitle => 'New entry';

  @override
  String get journalEntryFormEditTitle => 'Edit entry';

  @override
  String get journalFieldSummary => 'What happened?';

  @override
  String get journalAddPhoto => 'Add photo';

  @override
  String get journalPhotoSourceCamera => 'Camera';

  @override
  String get journalPhotoSourceGallery => 'Gallery';

  @override
  String get journalRemovePhoto => 'Remove photo';

  @override
  String get journalAddLocation => 'Add location';

  @override
  String get journalClearLocation => 'Clear location';

  @override
  String get journalDeleteEntryTitle => 'Delete this entry?';

  @override
  String get journalDeleteEntryBody =>
      'This removes its text and any photos. This can\'t be undone.';

  @override
  String get journalMapLocationHint =>
      'Entries without a location won\'t appear here.';

  @override
  String get journalUntitledEntry => 'Not written yet';

  @override
  String journalStatsLine(int entries, int places) {
    return '$entries entries · $places places visited';
  }

  @override
  String get journalPickNow => 'Now';

  @override
  String get journalPickToday => 'Today';

  @override
  String get journalPickYesterday => 'Yesterday';

  @override
  String get journalTripLocations => 'This trip\'s locations';

  @override
  String get journalNewLocation => 'New location';
}
