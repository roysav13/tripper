import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Tripper'**
  String get appTitle;

  /// No description provided for @tabTrips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get tabTrips;

  /// No description provided for @tabVault.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get tabVault;

  /// No description provided for @tabPlaces.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get tabPlaces;

  /// No description provided for @tripsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan your first trip'**
  String get tripsEmptyTitle;

  /// No description provided for @tripsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Dates, documents, and places — all in one pocket.'**
  String get tripsEmptyBody;

  /// No description provided for @tripsEmptyCta.
  ///
  /// In en, this message translates to:
  /// **'Create trip'**
  String get tripsEmptyCta;

  /// No description provided for @backupReminderBody.
  ///
  /// In en, this message translates to:
  /// **'Your trips live only on this device. Back them up so a lost phone doesn\'t mean a lost trip.'**
  String get backupReminderBody;

  /// No description provided for @backupReminderCta.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get backupReminderCta;

  /// No description provided for @errorStateTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong loading this'**
  String get errorStateTitle;

  /// No description provided for @errorStateBody.
  ///
  /// In en, this message translates to:
  /// **'Your data is still safe on this device. Try again.'**
  String get errorStateBody;

  /// No description provided for @errorStateRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get errorStateRetry;

  /// No description provided for @vaultEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your documents, ready anywhere'**
  String get vaultEmptyTitle;

  /// No description provided for @vaultEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Passport, tickets, bookings — stored only on this device.'**
  String get vaultEmptyBody;

  /// No description provided for @vaultEmptyCta.
  ///
  /// In en, this message translates to:
  /// **'Add document'**
  String get vaultEmptyCta;

  /// No description provided for @placesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Where to next?'**
  String get placesEmptyTitle;

  /// No description provided for @placesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Keep a list of places you want to see, and the ones you already have.'**
  String get placesEmptyBody;

  /// No description provided for @placesEmptyCta.
  ///
  /// In en, this message translates to:
  /// **'Add place'**
  String get placesEmptyCta;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @sectionActive.
  ///
  /// In en, this message translates to:
  /// **'Active now'**
  String get sectionActive;

  /// No description provided for @sectionUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get sectionUpcoming;

  /// No description provided for @sectionPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get sectionPlanned;

  /// No description provided for @sectionPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get sectionPast;

  /// No description provided for @sectionArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get sectionArchived;

  /// No description provided for @datesTbd.
  ///
  /// In en, this message translates to:
  /// **'Dates TBD'**
  String get datesTbd;

  /// No description provided for @fromDate.
  ///
  /// In en, this message translates to:
  /// **'From {date}'**
  String fromDate(String date);

  /// No description provided for @tripDayOpen.
  ///
  /// In en, this message translates to:
  /// **'Day {n}'**
  String tripDayOpen(int n);

  /// No description provided for @themeToggleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch theme'**
  String get themeToggleTooltip;

  /// No description provided for @tripDayCount.
  ///
  /// In en, this message translates to:
  /// **'Day {n} of {m}'**
  String tripDayCount(int n, int m);

  /// No description provided for @tripFormTitleNew.
  ///
  /// In en, this message translates to:
  /// **'New trip'**
  String get tripFormTitleNew;

  /// No description provided for @tripFormTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit trip'**
  String get tripFormTitleEdit;

  /// No description provided for @tripFormName.
  ///
  /// In en, this message translates to:
  /// **'Trip name'**
  String get tripFormName;

  /// No description provided for @tripFormDestinations.
  ///
  /// In en, this message translates to:
  /// **'Destinations'**
  String get tripFormDestinations;

  /// No description provided for @tripFormAddDestination.
  ///
  /// In en, this message translates to:
  /// **'Add destination'**
  String get tripFormAddDestination;

  /// No description provided for @tripFormAddDestinationHint.
  ///
  /// In en, this message translates to:
  /// **'Krabi'**
  String get tripFormAddDestinationHint;

  /// No description provided for @tripFormDates.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get tripFormDates;

  /// No description provided for @tripFormDatesHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — leave empty while planning, or set only a start for one-way trips.'**
  String get tripFormDatesHint;

  /// No description provided for @tripFormStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get tripFormStartDate;

  /// No description provided for @tripFormEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get tripFormEndDate;

  /// No description provided for @tripFormCoverPhoto.
  ///
  /// In en, this message translates to:
  /// **'Cover photo'**
  String get tripFormCoverPhoto;

  /// No description provided for @tripFormCoverPhotoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That photo is too large — try a smaller one.'**
  String get tripFormCoverPhotoTooLarge;

  /// No description provided for @errEndWithoutStart.
  ///
  /// In en, this message translates to:
  /// **'Set a start date first'**
  String get errEndWithoutStart;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @errNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Give the trip a name'**
  String get errNameRequired;

  /// No description provided for @errNoDestination.
  ///
  /// In en, this message translates to:
  /// **'Add at least one destination'**
  String get errNoDestination;

  /// No description provided for @errDatesRequired.
  ///
  /// In en, this message translates to:
  /// **'Pick valid start and end dates'**
  String get errDatesRequired;

  /// No description provided for @menuEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get menuEdit;

  /// No description provided for @menuRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get menuRename;

  /// No description provided for @menuArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get menuArchive;

  /// No description provided for @menuUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get menuUnarchive;

  /// No description provided for @menuDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get menuDelete;

  /// No description provided for @deleteTripTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this trip?'**
  String get deleteTripTitle;

  /// No description provided for @deleteTripBody.
  ///
  /// In en, this message translates to:
  /// **'The trip is removed. Documents and places linked to it are kept.'**
  String get deleteTripBody;

  /// No description provided for @tabDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get tabDocuments;

  /// No description provided for @tabPlacesInTrip.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get tabPlacesInTrip;

  /// No description provided for @tabExpenses.
  ///
  /// In en, this message translates to:
  /// **'Spend'**
  String get tabExpenses;

  /// No description provided for @tabPacking.
  ///
  /// In en, this message translates to:
  /// **'Packing'**
  String get tabPacking;

  /// No description provided for @expensesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Track what this trip costs'**
  String get expensesEmptyTitle;

  /// No description provided for @expensesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add what you spend as you go — the total and a category breakdown build up here.'**
  String get expensesEmptyBody;

  /// No description provided for @expensesEmptyCta.
  ///
  /// In en, this message translates to:
  /// **'Add an expense'**
  String get expensesEmptyCta;

  /// No description provided for @expensesTotal.
  ///
  /// In en, this message translates to:
  /// **'Total spent'**
  String get expensesTotal;

  /// No description provided for @expensesConvertedTotal.
  ///
  /// In en, this message translates to:
  /// **'≈ {amount} {currency}'**
  String expensesConvertedTotal(String amount, String currency);

  /// No description provided for @expensesConversionPending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 expense not converted yet} other{{count} expenses not converted yet}}'**
  String expensesConversionPending(int count);

  /// No description provided for @expensesConversionOffHint.
  ///
  /// In en, this message translates to:
  /// **'Set a home currency in Settings to see one combined total.'**
  String get expensesConversionOffHint;

  /// No description provided for @expensesRatesAsOf.
  ///
  /// In en, this message translates to:
  /// **'Rates from {date}'**
  String expensesRatesAsOf(String date);

  /// No description provided for @expensesTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get expensesTodayLabel;

  /// No description provided for @expensesNoSpendToday.
  ///
  /// In en, this message translates to:
  /// **'No spend yet'**
  String get expensesNoSpendToday;

  /// No description provided for @expensesFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get expensesFilterAll;

  /// No description provided for @expensesFilterEmpty.
  ///
  /// In en, this message translates to:
  /// **'No expenses match this filter.'**
  String get expensesFilterEmpty;

  /// No description provided for @expenseGroupWeekOf.
  ///
  /// In en, this message translates to:
  /// **'Week of {date}'**
  String expenseGroupWeekOf(String date);

  /// No description provided for @settingsHomeCurrency.
  ///
  /// In en, this message translates to:
  /// **'Home currency'**
  String get settingsHomeCurrency;

  /// No description provided for @settingsHomeCurrencyHint.
  ///
  /// In en, this message translates to:
  /// **'Converts mixed-currency trip totals into one figure. Needs a connection the first time; converted amounts are then stored and work offline. Leave empty to just list each currency.'**
  String get settingsHomeCurrencyHint;

  /// No description provided for @settingsHomeCurrencyOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsHomeCurrencyOff;

  /// No description provided for @currencyPickerSearch.
  ///
  /// In en, this message translates to:
  /// **'Search currency'**
  String get currencyPickerSearch;

  /// No description provided for @currencyPickerOffHint.
  ///
  /// In en, this message translates to:
  /// **'Show each currency separately, no conversion.'**
  String get currencyPickerOffHint;

  /// No description provided for @currencyPickerNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No currency matches that.'**
  String get currencyPickerNoMatch;

  /// No description provided for @expenseFormTitle.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get expenseFormTitle;

  /// No description provided for @expenseFormEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit expense'**
  String get expenseFormEditTitle;

  /// No description provided for @expenseFormAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get expenseFormAmount;

  /// No description provided for @expenseFormCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get expenseFormCurrency;

  /// No description provided for @expenseFormNotes.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get expenseFormNotes;

  /// No description provided for @expenseFormDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get expenseFormDate;

  /// No description provided for @errAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount like 12.30'**
  String get errAmountRequired;

  /// No description provided for @errCurrencyRequired.
  ///
  /// In en, this message translates to:
  /// **'Use a 3-letter code, e.g. ILS'**
  String get errCurrencyRequired;

  /// No description provided for @expenseDeleted.
  ///
  /// In en, this message translates to:
  /// **'Expense deleted.'**
  String get expenseDeleted;

  /// No description provided for @catFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get catFood;

  /// No description provided for @catActivities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get catActivities;

  /// No description provided for @catShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get catShopping;

  /// No description provided for @tripDocsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No documents linked'**
  String get tripDocsEmptyTitle;

  /// No description provided for @tripDocsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Flights, stays, and tickets for this trip will live here.'**
  String get tripDocsEmptyBody;

  /// No description provided for @vaultPinnedSection.
  ///
  /// In en, this message translates to:
  /// **'Pinned · quick access'**
  String get vaultPinnedSection;

  /// No description provided for @vaultAllSection.
  ///
  /// In en, this message translates to:
  /// **'All documents'**
  String get vaultAllSection;

  /// No description provided for @vaultSortCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get vaultSortCreated;

  /// No description provided for @vaultSortRelevant.
  ///
  /// In en, this message translates to:
  /// **'Relevant date'**
  String get vaultSortRelevant;

  /// No description provided for @vaultFilterCategorySection.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get vaultFilterCategorySection;

  /// No description provided for @vaultFilterShowResults.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Show 1 document} other{Show {count} documents}}'**
  String vaultFilterShowResults(int count);

  /// No description provided for @vaultCategoryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 document} other{{count} documents}}'**
  String vaultCategoryCount(int count);

  /// No description provided for @catPassport.
  ///
  /// In en, this message translates to:
  /// **'Passport / ID'**
  String get catPassport;

  /// No description provided for @catVisa.
  ///
  /// In en, this message translates to:
  /// **'Visa'**
  String get catVisa;

  /// No description provided for @catFlight.
  ///
  /// In en, this message translates to:
  /// **'Flight'**
  String get catFlight;

  /// No description provided for @catStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get catStay;

  /// No description provided for @catInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get catInsurance;

  /// No description provided for @catTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get catTransport;

  /// No description provided for @catOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get catOther;

  /// No description provided for @manualRecord.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manualRecord;

  /// No description provided for @expiryShort.
  ///
  /// In en, this message translates to:
  /// **'Exp {date}'**
  String expiryShort(String date);

  /// No description provided for @docFormTitle.
  ///
  /// In en, this message translates to:
  /// **'Add document'**
  String get docFormTitle;

  /// No description provided for @docFormName.
  ///
  /// In en, this message translates to:
  /// **'Document name'**
  String get docFormName;

  /// No description provided for @docFormAttachFile.
  ///
  /// In en, this message translates to:
  /// **'Attach file'**
  String get docFormAttachFile;

  /// No description provided for @docFormExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry date'**
  String get docFormExpiry;

  /// No description provided for @docFormGlobal.
  ///
  /// In en, this message translates to:
  /// **'Keep in global vault'**
  String get docFormGlobal;

  /// No description provided for @docFormGlobalHint.
  ///
  /// In en, this message translates to:
  /// **'For documents that outlive trips — passport, license, insurance.'**
  String get docFormGlobalHint;

  /// No description provided for @fieldFlightNumber.
  ///
  /// In en, this message translates to:
  /// **'Flight number'**
  String get fieldFlightNumber;

  /// No description provided for @fieldConfirmationCode.
  ///
  /// In en, this message translates to:
  /// **'Confirmation code'**
  String get fieldConfirmationCode;

  /// No description provided for @docFormDepartureTime.
  ///
  /// In en, this message translates to:
  /// **'Departure time'**
  String get docFormDepartureTime;

  /// No description provided for @docFormDepartureTimeHint.
  ///
  /// In en, this message translates to:
  /// **'Powers the check-in-opens reminder (M5.3) — optional.'**
  String get docFormDepartureTimeHint;

  /// No description provided for @docOcrPrefilled.
  ///
  /// In en, this message translates to:
  /// **'Filled in from the photo — double-check before saving.'**
  String get docOcrPrefilled;

  /// No description provided for @docTitleFlight.
  ///
  /// In en, this message translates to:
  /// **'Flight {number}'**
  String docTitleFlight(String number);

  /// No description provided for @fieldBookingRef.
  ///
  /// In en, this message translates to:
  /// **'Booking reference'**
  String get fieldBookingRef;

  /// No description provided for @fieldDocumentNumber.
  ///
  /// In en, this message translates to:
  /// **'Document number'**
  String get fieldDocumentNumber;

  /// No description provided for @docActionOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get docActionOpen;

  /// No description provided for @showCodeAction.
  ///
  /// In en, this message translates to:
  /// **'Show at gate'**
  String get showCodeAction;

  /// No description provided for @showCodeFileMissing.
  ///
  /// In en, this message translates to:
  /// **'This document\'s file is missing. Re-attach it from the vault.'**
  String get showCodeFileMissing;

  /// No description provided for @showCodePdfFallback.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t display this PDF here. Open it in a viewer instead.'**
  String get showCodePdfFallback;

  /// No description provided for @docActionPin.
  ///
  /// In en, this message translates to:
  /// **'Pin for quick access'**
  String get docActionPin;

  /// No description provided for @docActionUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get docActionUnpin;

  /// No description provided for @docActionLink.
  ///
  /// In en, this message translates to:
  /// **'Link to trips'**
  String get docActionLink;

  /// No description provided for @pinLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Up to 4 documents can be pinned. Unpin one first.'**
  String get pinLimitReached;

  /// No description provided for @noTripsToLink.
  ///
  /// In en, this message translates to:
  /// **'No trips yet — create one first.'**
  String get noTripsToLink;

  /// No description provided for @docLinksUpdated.
  ///
  /// In en, this message translates to:
  /// **'Trip links updated.'**
  String get docLinksUpdated;

  /// No description provided for @docLinksUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update trip links. Try again.'**
  String get docLinksUpdateFailed;

  /// No description provided for @vaultLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Vault locked'**
  String get vaultLockedTitle;

  /// No description provided for @vaultLockedBody.
  ///
  /// In en, this message translates to:
  /// **'Your documents are protected by your device lock.'**
  String get vaultLockedBody;

  /// No description provided for @unlockCta.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlockCta;

  /// No description provided for @unlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock your document vault'**
  String get unlockReason;

  /// No description provided for @unlockSettingsReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Tripper settings'**
  String get unlockSettingsReason;

  /// No description provided for @settingsLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings locked'**
  String get settingsLockedTitle;

  /// No description provided for @settingsLockedBody.
  ///
  /// In en, this message translates to:
  /// **'Backup and security options are protected by your device lock.'**
  String get settingsLockedBody;

  /// No description provided for @deleteDocTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this document?'**
  String get deleteDocTitle;

  /// No description provided for @deleteDocBody.
  ///
  /// In en, this message translates to:
  /// **'The document and its file are removed from this device.'**
  String get deleteDocBody;

  /// No description provided for @expiryTripWarning.
  ///
  /// In en, this message translates to:
  /// **'{title} expires too close to this trip\'s end. Check entry requirements.'**
  String expiryTripWarning(String title);

  /// No description provided for @tripPlacesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No places yet'**
  String get tripPlacesEmptyTitle;

  /// No description provided for @tripPlacesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Track what you want to see on this trip.'**
  String get tripPlacesEmptyBody;

  /// No description provided for @placesWantSection.
  ///
  /// In en, this message translates to:
  /// **'Want to go'**
  String get placesWantSection;

  /// No description provided for @placesBeenSection.
  ///
  /// In en, this message translates to:
  /// **'Been there'**
  String get placesBeenSection;

  /// No description provided for @placeMarkVisited.
  ///
  /// In en, this message translates to:
  /// **'Mark as visited'**
  String get placeMarkVisited;

  /// No description provided for @placeViewOnMap.
  ///
  /// In en, this message translates to:
  /// **'View on map'**
  String get placeViewOnMap;

  /// No description provided for @placeOpenInGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Google Maps'**
  String get placeOpenInGoogleMaps;

  /// No description provided for @placeOpenMapsFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open Google Maps.'**
  String get placeOpenMapsFailed;

  /// No description provided for @placeUnvisit.
  ///
  /// In en, this message translates to:
  /// **'Move back to wishlist'**
  String get placeUnvisit;

  /// No description provided for @placeSummaryShow.
  ///
  /// In en, this message translates to:
  /// **'View summary'**
  String get placeSummaryShow;

  /// No description provided for @placeSummaryHide.
  ///
  /// In en, this message translates to:
  /// **'Hide summary'**
  String get placeSummaryHide;

  /// No description provided for @visitedOn.
  ///
  /// In en, this message translates to:
  /// **'Visited {date}'**
  String visitedOn(String date);

  /// No description provided for @placeFormTitle.
  ///
  /// In en, this message translates to:
  /// **'Add place'**
  String get placeFormTitle;

  /// No description provided for @placeFormName.
  ///
  /// In en, this message translates to:
  /// **'Place name'**
  String get placeFormName;

  /// No description provided for @placeFormCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get placeFormCity;

  /// No description provided for @placeFormCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get placeFormCountry;

  /// No description provided for @placeFormTrip.
  ///
  /// In en, this message translates to:
  /// **'Link to a trip'**
  String get placeFormTrip;

  /// No description provided for @placeFormDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get placeFormDescription;

  /// No description provided for @catHotel.
  ///
  /// In en, this message translates to:
  /// **'Hotel'**
  String get catHotel;

  /// No description provided for @catRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get catRestaurant;

  /// No description provided for @catCoffeeShop.
  ///
  /// In en, this message translates to:
  /// **'Coffee Shop'**
  String get catCoffeeShop;

  /// No description provided for @catBar.
  ///
  /// In en, this message translates to:
  /// **'Bar'**
  String get catBar;

  /// No description provided for @catAttraction.
  ///
  /// In en, this message translates to:
  /// **'Attraction'**
  String get catAttraction;

  /// No description provided for @catMuseum.
  ///
  /// In en, this message translates to:
  /// **'Museum'**
  String get catMuseum;

  /// No description provided for @catAmusementPark.
  ///
  /// In en, this message translates to:
  /// **'Amusement Park'**
  String get catAmusementPark;

  /// No description provided for @catTrek.
  ///
  /// In en, this message translates to:
  /// **'Trek'**
  String get catTrek;

  /// No description provided for @catBeach.
  ///
  /// In en, this message translates to:
  /// **'Beach'**
  String get catBeach;

  /// No description provided for @catNature.
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get catNature;

  /// No description provided for @mapViewToggle.
  ///
  /// In en, this message translates to:
  /// **'Map view'**
  String get mapViewToggle;

  /// No description provided for @listViewToggle.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get listViewToggle;

  /// No description provided for @filterClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get filterClearAll;

  /// No description provided for @filterClearAction.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get filterClearAction;

  /// No description provided for @filterButtonTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filterButtonTooltip;

  /// No description provided for @filterSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filterSheetTitle;

  /// No description provided for @sortButtonTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortButtonTooltip;

  /// No description provided for @sortSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortSheetTitle;

  /// No description provided for @sortAToZ.
  ///
  /// In en, this message translates to:
  /// **'A–Z'**
  String get sortAToZ;

  /// No description provided for @sortZToA.
  ///
  /// In en, this message translates to:
  /// **'Z–A'**
  String get sortZToA;

  /// No description provided for @sortOldestFirst.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get sortOldestFirst;

  /// No description provided for @sortNewestFirst.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get sortNewestFirst;

  /// No description provided for @sortNearestFirst.
  ///
  /// In en, this message translates to:
  /// **'Nearest first'**
  String get sortNearestFirst;

  /// No description provided for @sortFarthestFirst.
  ///
  /// In en, this message translates to:
  /// **'Farthest first'**
  String get sortFarthestFirst;

  /// No description provided for @placesSortRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get placesSortRecommended;

  /// No description provided for @placesSortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get placesSortName;

  /// No description provided for @placesSortVisitedDate.
  ///
  /// In en, this message translates to:
  /// **'Date visited'**
  String get placesSortVisitedDate;

  /// No description provided for @placesSortDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get placesSortDistance;

  /// No description provided for @placesSortDistanceFetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching your location…'**
  String get placesSortDistanceFetching;

  /// No description provided for @placesSortDistanceServiceDisabled.
  ///
  /// In en, this message translates to:
  /// **'Turn on location services to sort by distance'**
  String get placesSortDistanceServiceDisabled;

  /// No description provided for @placesSortDistancePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Allow location access to sort by distance'**
  String get placesSortDistancePermissionDenied;

  /// No description provided for @placesSortDistanceError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get your location'**
  String get placesSortDistanceError;

  /// No description provided for @placesSortDistanceRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get placesSortDistanceRetry;

  /// No description provided for @placesSortDistanceOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get placesSortDistanceOpenSettings;

  /// No description provided for @placeDistanceKmAway.
  ///
  /// In en, this message translates to:
  /// **'{km} km away'**
  String placeDistanceKmAway(String km);

  /// No description provided for @placeDistanceMetersAway.
  ///
  /// In en, this message translates to:
  /// **'{m} m away'**
  String placeDistanceMetersAway(int m);

  /// No description provided for @placesFilterButton.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get placesFilterButton;

  /// No description provided for @placesFilterSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get placesFilterSheetTitle;

  /// No description provided for @placesFilterEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No places match'**
  String get placesFilterEmptyTitle;

  /// No description provided for @placesFilterEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Try a different category or country, or clear your filters to see everything again.'**
  String get placesFilterEmptyBody;

  /// No description provided for @placesFilterEmptyCta.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get placesFilterEmptyCta;

  /// No description provided for @placesFilterCategorySection.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get placesFilterCategorySection;

  /// No description provided for @placesFilterCountrySection.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get placesFilterCountrySection;

  /// No description provided for @placesFilterSearchCountry.
  ///
  /// In en, this message translates to:
  /// **'Search countries'**
  String get placesFilterSearchCountry;

  /// No description provided for @placesFilterSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No countries match'**
  String get placesFilterSearchNoResults;

  /// No description provided for @placesFilterShowResults.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Show 1 place} other{Show {count} places}}'**
  String placesFilterShowResults(int count);

  /// No description provided for @placesFilterListsSection.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get placesFilterListsSection;

  /// No description provided for @placesFilterSearchList.
  ///
  /// In en, this message translates to:
  /// **'Search lists'**
  String get placesFilterSearchList;

  /// No description provided for @placesFilterSearchNoListsResults.
  ///
  /// In en, this message translates to:
  /// **'No lists match'**
  String get placesFilterSearchNoListsResults;

  /// No description provided for @newListChipLabel.
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get newListChipLabel;

  /// No description provided for @newListDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get newListDialogTitle;

  /// No description provided for @newListDialogNameLabel.
  ///
  /// In en, this message translates to:
  /// **'List name'**
  String get newListDialogNameLabel;

  /// No description provided for @newListDialogCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get newListDialogCreate;

  /// No description provided for @errListNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Give the list a name'**
  String get errListNameRequired;

  /// No description provided for @renameListMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Rename list'**
  String get renameListMenuItem;

  /// No description provided for @renameListDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename list'**
  String get renameListDialogTitle;

  /// No description provided for @deleteListMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Delete list'**
  String get deleteListMenuItem;

  /// No description provided for @deleteListTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this list?'**
  String get deleteListTitle;

  /// No description provided for @deleteListBody.
  ///
  /// In en, this message translates to:
  /// **'Places stay right where they are — only the list itself goes away.'**
  String get deleteListBody;

  /// No description provided for @listDetailEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No places yet'**
  String get listDetailEmptyTitle;

  /// No description provided for @listDetailEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add places to this list from their edit screen.'**
  String get listDetailEmptyBody;

  /// No description provided for @listDetailEmptyCta.
  ///
  /// In en, this message translates to:
  /// **'Browse places'**
  String get listDetailEmptyCta;

  /// No description provided for @listDetailPlaceCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 place} other{{count} places}}'**
  String listDetailPlaceCount(int count);

  /// No description provided for @nearbyEntryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Find nearby'**
  String get nearbyEntryTooltip;

  /// No description provided for @nearbyAnchorNearMe.
  ///
  /// In en, this message translates to:
  /// **'Near me'**
  String get nearbyAnchorNearMe;

  /// No description provided for @nearbyAnchorNearMeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Turn on location to use this'**
  String get nearbyAnchorNearMeUnavailable;

  /// No description provided for @nearbyAnchorSavedPlace.
  ///
  /// In en, this message translates to:
  /// **'Near a saved place'**
  String get nearbyAnchorSavedPlace;

  /// No description provided for @nearbyAnchorNoSavedPlaces.
  ///
  /// In en, this message translates to:
  /// **'No saved places with a location yet'**
  String get nearbyAnchorNoSavedPlaces;

  /// No description provided for @nearbyResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get nearbyResultsTitle;

  /// No description provided for @nearbyFindButton.
  ///
  /// In en, this message translates to:
  /// **'Find nearby'**
  String get nearbyFindButton;

  /// No description provided for @nearbyEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No highly-rated places found'**
  String get nearbyEmptyTitle;

  /// No description provided for @nearbyEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Try a different anchor, or check back later — nearby results can change.'**
  String get nearbyEmptyBody;

  /// No description provided for @nearbyAddToWishlist.
  ///
  /// In en, this message translates to:
  /// **'Add to wishlist'**
  String get nearbyAddToWishlist;

  /// No description provided for @nearbyDayPickerPrompt.
  ///
  /// In en, this message translates to:
  /// **'Assign a day'**
  String get nearbyDayPickerPrompt;

  /// No description provided for @nearbyDayNumber.
  ///
  /// In en, this message translates to:
  /// **'Day {n}'**
  String nearbyDayNumber(int n);

  /// No description provided for @journalGlobeLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading globe'**
  String get journalGlobeLoading;

  /// No description provided for @journalGlobeClusterCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 entry} other{{count} entries}}'**
  String journalGlobeClusterCount(int count);

  /// No description provided for @pickOnMap.
  ///
  /// In en, this message translates to:
  /// **'Pick on map'**
  String get pickOnMap;

  /// No description provided for @pickOnMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Drop a pin'**
  String get pickOnMapTitle;

  /// No description provided for @pickOnMapHint.
  ///
  /// In en, this message translates to:
  /// **'Search above, or long-press the map to place the pin'**
  String get pickOnMapHint;

  /// No description provided for @mapSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for a place'**
  String get mapSearchHint;

  /// No description provided for @mapSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results — try a different spelling.'**
  String get mapSearchNoResults;

  /// No description provided for @mapSearchOffline.
  ///
  /// In en, this message translates to:
  /// **'Search needs a connection. Long-press the map instead.'**
  String get mapSearchOffline;

  /// No description provided for @mapLayersButton.
  ///
  /// In en, this message translates to:
  /// **'Map layers'**
  String get mapLayersButton;

  /// No description provided for @mapLayerNormal.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get mapLayerNormal;

  /// No description provided for @mapLayerSatellite.
  ///
  /// In en, this message translates to:
  /// **'Satellite'**
  String get mapLayerSatellite;

  /// No description provided for @mapLayerTerrain.
  ///
  /// In en, this message translates to:
  /// **'Terrain'**
  String get mapLayerTerrain;

  /// No description provided for @addWithoutLocation.
  ///
  /// In en, this message translates to:
  /// **'Add \"{query}\" without a location'**
  String addWithoutLocation(String query);

  /// No description provided for @noLocationChip.
  ///
  /// In en, this message translates to:
  /// **'No location'**
  String get noLocationChip;

  /// No description provided for @editPlaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit place'**
  String get editPlaceTitle;

  /// No description provided for @deletePlaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this place?'**
  String get deletePlaceTitle;

  /// No description provided for @deletePlaceBody.
  ///
  /// In en, this message translates to:
  /// **'The place is removed from your lists and the map.'**
  String get deletePlaceBody;

  /// No description provided for @deleteExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this expense?'**
  String get deleteExpenseTitle;

  /// No description provided for @deleteExpenseBody.
  ///
  /// In en, this message translates to:
  /// **'This removes it from the trip\'s total.'**
  String get deleteExpenseBody;

  /// No description provided for @tripCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip finished — update your map?'**
  String get tripCompleteTitle;

  /// No description provided for @tripCompleteBody.
  ///
  /// In en, this message translates to:
  /// **'{trip} is over. Mark the places you got to as visited:'**
  String tripCompleteBody(String trip);

  /// No description provided for @tripCompleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Mark visited'**
  String get tripCompleteConfirm;

  /// No description provided for @tripCompleteSkip.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get tripCompleteSkip;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageHebrew.
  ///
  /// In en, this message translates to:
  /// **'עברית'**
  String get languageHebrew;

  /// No description provided for @settingsSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecurity;

  /// No description provided for @settingsVaultLock.
  ///
  /// In en, this message translates to:
  /// **'Lock the vault'**
  String get settingsVaultLock;

  /// No description provided for @settingsVaultLockHint.
  ///
  /// In en, this message translates to:
  /// **'Ask for your fingerprint before opening documents.'**
  String get settingsVaultLockHint;

  /// No description provided for @settingsBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get settingsBackup;

  /// No description provided for @settingsBackupHint.
  ///
  /// In en, this message translates to:
  /// **'Everything lives on this device only. Export a backup you can restore after a reinstall or on a new phone.'**
  String get settingsBackupHint;

  /// No description provided for @settingsExport.
  ///
  /// In en, this message translates to:
  /// **'Export backup'**
  String get settingsExport;

  /// No description provided for @settingsExportShareText.
  ///
  /// In en, this message translates to:
  /// **'Tripper backup'**
  String get settingsExportShareText;

  /// No description provided for @settingsExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the backup. Try again.'**
  String get settingsExportFailed;

  /// No description provided for @settingsImport.
  ///
  /// In en, this message translates to:
  /// **'Restore backup'**
  String get settingsImport;

  /// No description provided for @settingsImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup?'**
  String get settingsImportTitle;

  /// No description provided for @settingsImportWarning.
  ///
  /// In en, this message translates to:
  /// **'This replaces every trip, document, and place on this device with the backup\'s contents.'**
  String get settingsImportWarning;

  /// No description provided for @settingsImportDone.
  ///
  /// In en, this message translates to:
  /// **'Backup restored. Restart Tripper to see it.'**
  String get settingsImportDone;

  /// No description provided for @settingsImportCorrupt.
  ///
  /// In en, this message translates to:
  /// **'That file isn\'t a valid Tripper backup.'**
  String get settingsImportCorrupt;

  /// No description provided for @settingsImportTooNew.
  ///
  /// In en, this message translates to:
  /// **'That backup came from a newer version of Tripper.'**
  String get settingsImportTooNew;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsExpiryNoticeHint.
  ///
  /// In en, this message translates to:
  /// **'How far ahead of a document\'s expiry date counts as coming up.'**
  String get settingsExpiryNoticeHint;

  /// No description provided for @settingsExpiryNoticeOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsExpiryNoticeOff;

  /// No description provided for @settingsNearbyPlaces.
  ///
  /// In en, this message translates to:
  /// **'Nearby places'**
  String get settingsNearbyPlaces;

  /// No description provided for @settingsNearbyPlacesHint.
  ///
  /// In en, this message translates to:
  /// **'Find highly-rated places near you or a saved spot, right from the Places tab.'**
  String get settingsNearbyPlacesHint;

  /// No description provided for @settingsNearbyPlacesCallCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 lookup this install} other{{count} lookups this install}}'**
  String settingsNearbyPlacesCallCount(int count);

  /// No description provided for @settingsNearbyPlacesNoKey.
  ///
  /// In en, this message translates to:
  /// **'Requires a Maps API key to be configured'**
  String get settingsNearbyPlacesNoKey;

  /// No description provided for @docExpiryNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'{title} expires soon'**
  String docExpiryNotificationTitle(String title);

  /// No description provided for @docExpiryNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}.'**
  String docExpiryNotificationBody(String date);

  /// No description provided for @tripCountdownNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} starts soon'**
  String tripCountdownNotificationTitle(String name);

  /// No description provided for @tripCountdownNotificationBodyClear.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{Starts in 1 day} other{Starts in {days} days}} — everything\'s in order.'**
  String tripCountdownNotificationBodyClear(int days);

  /// No description provided for @tripCountdownNotificationBodyWithIssues.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{Starts in 1 day} other{Starts in {days} days}} — {count, plural, one{1 document needs} other{{count} documents need}} attention.'**
  String tripCountdownNotificationBodyWithIssues(int days, int count);

  /// No description provided for @checkInNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Check-in opens for {title}'**
  String checkInNotificationTitle(String title);

  /// No description provided for @checkInNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'Check-in usually opens 24 hours before departure. Airlines vary this 24–48h, so double-check with yours.'**
  String get checkInNotificationBody;

  /// No description provided for @placeFormNoTrip.
  ///
  /// In en, this message translates to:
  /// **'No trip'**
  String get placeFormNoTrip;

  /// No description provided for @videoCaptureTitle.
  ///
  /// In en, this message translates to:
  /// **'Capture place from video'**
  String get videoCaptureTitle;

  /// No description provided for @videoCaptureFetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching…'**
  String get videoCaptureFetching;

  /// No description provided for @videoCaptureFetchFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t fetch this video'**
  String get videoCaptureFetchFailedTitle;

  /// No description provided for @videoCaptureFetchFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Try sharing the link again, or add the place manually from the Places tab.'**
  String get videoCaptureFetchFailedBody;

  /// No description provided for @videoCaptureRecognizedLabel.
  ///
  /// In en, this message translates to:
  /// **'Recognized text'**
  String get videoCaptureRecognizedLabel;

  /// No description provided for @videoCaptureRecognizedHint.
  ///
  /// In en, this message translates to:
  /// **'Edit before continuing — check it\'s right'**
  String get videoCaptureRecognizedHint;

  /// No description provided for @videoCaptureNoTextFound.
  ///
  /// In en, this message translates to:
  /// **'No text found in this frame — you can type it in'**
  String get videoCaptureNoTextFound;

  /// No description provided for @videoCaptureLookUp.
  ///
  /// In en, this message translates to:
  /// **'Look up'**
  String get videoCaptureLookUp;

  /// No description provided for @placeCandidateReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review place'**
  String get placeCandidateReviewTitle;

  /// No description provided for @placeCandidateReviewLookingUp.
  ///
  /// In en, this message translates to:
  /// **'Looking up…'**
  String get placeCandidateReviewLookingUp;

  /// No description provided for @placeCandidateReviewNoSummary.
  ///
  /// In en, this message translates to:
  /// **'No summary found'**
  String get placeCandidateReviewNoSummary;

  /// No description provided for @placeCandidateReviewNoLocation.
  ///
  /// In en, this message translates to:
  /// **'No location found — you can add one manually next'**
  String get placeCandidateReviewNoLocation;

  /// No description provided for @placeCandidateReviewConfirm.
  ///
  /// In en, this message translates to:
  /// **'Add this place'**
  String get placeCandidateReviewConfirm;

  /// No description provided for @placeCandidateReviewCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get placeCandidateReviewCancel;

  /// No description provided for @tripPlacesProgress.
  ///
  /// In en, this message translates to:
  /// **'{visited} of {total} visited'**
  String tripPlacesProgress(int visited, int total);

  /// No description provided for @tabJournal.
  ///
  /// In en, this message translates to:
  /// **'Journal'**
  String get tabJournal;

  /// No description provided for @journalEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No journal entries yet'**
  String get journalEmptyTitle;

  /// No description provided for @journalEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Log a note from the road — where you went and what happened.'**
  String get journalEmptyBody;

  /// No description provided for @journalAddEntryCta.
  ///
  /// In en, this message translates to:
  /// **'Add entry'**
  String get journalAddEntryCta;

  /// No description provided for @journalEntryFormTitle.
  ///
  /// In en, this message translates to:
  /// **'New entry'**
  String get journalEntryFormTitle;

  /// No description provided for @journalEntryFormEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit entry'**
  String get journalEntryFormEditTitle;

  /// No description provided for @journalFieldSummary.
  ///
  /// In en, this message translates to:
  /// **'What happened?'**
  String get journalFieldSummary;

  /// No description provided for @journalAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get journalAddPhoto;

  /// No description provided for @journalPhotoSourceCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get journalPhotoSourceCamera;

  /// No description provided for @journalPhotoSourceGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get journalPhotoSourceGallery;

  /// No description provided for @journalRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get journalRemovePhoto;

  /// No description provided for @journalAddLocation.
  ///
  /// In en, this message translates to:
  /// **'Add location'**
  String get journalAddLocation;

  /// No description provided for @journalClearLocation.
  ///
  /// In en, this message translates to:
  /// **'Clear location'**
  String get journalClearLocation;

  /// No description provided for @journalDeleteEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this entry?'**
  String get journalDeleteEntryTitle;

  /// No description provided for @journalDeleteEntryBody.
  ///
  /// In en, this message translates to:
  /// **'This removes its text and any photos. This can\'t be undone.'**
  String get journalDeleteEntryBody;

  /// No description provided for @journalMapLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Entries without a location won\'t appear here.'**
  String get journalMapLocationHint;

  /// No description provided for @journalUntitledEntry.
  ///
  /// In en, this message translates to:
  /// **'Not written yet'**
  String get journalUntitledEntry;

  /// No description provided for @journalStatsLine.
  ///
  /// In en, this message translates to:
  /// **'{entries} entries · {places} places visited'**
  String journalStatsLine(int entries, int places);

  /// No description provided for @journalPickNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get journalPickNow;

  /// No description provided for @journalPickToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get journalPickToday;

  /// No description provided for @journalPickYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get journalPickYesterday;

  /// No description provided for @journalTripLocations.
  ///
  /// In en, this message translates to:
  /// **'This trip\'s locations'**
  String get journalTripLocations;

  /// No description provided for @journalNewLocation.
  ///
  /// In en, this message translates to:
  /// **'New location'**
  String get journalNewLocation;

  /// No description provided for @packingEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing packed yet'**
  String get packingEmptyTitle;

  /// No description provided for @packingEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add items yourself, or apply a saved template to get started.'**
  String get packingEmptyBody;

  /// No description provided for @packingEmptyCta.
  ///
  /// In en, this message translates to:
  /// **'Add an item'**
  String get packingEmptyCta;

  /// No description provided for @packingCatClothing.
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get packingCatClothing;

  /// No description provided for @packingCatDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get packingCatDocuments;

  /// No description provided for @packingCatElectronics.
  ///
  /// In en, this message translates to:
  /// **'Electronics'**
  String get packingCatElectronics;

  /// No description provided for @packingCatToiletries.
  ///
  /// In en, this message translates to:
  /// **'Toiletries'**
  String get packingCatToiletries;

  /// No description provided for @packingCatOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get packingCatOther;

  /// No description provided for @packingStatusToPack.
  ///
  /// In en, this message translates to:
  /// **'To pack'**
  String get packingStatusToPack;

  /// No description provided for @packingStatusPacked.
  ///
  /// In en, this message translates to:
  /// **'Packed'**
  String get packingStatusPacked;

  /// No description provided for @packingStatusWorn.
  ///
  /// In en, this message translates to:
  /// **'Worn'**
  String get packingStatusWorn;

  /// No description provided for @packingStatusInWash.
  ///
  /// In en, this message translates to:
  /// **'In wash'**
  String get packingStatusInWash;

  /// No description provided for @packingStatusClean.
  ///
  /// In en, this message translates to:
  /// **'Clean'**
  String get packingStatusClean;

  /// No description provided for @deletePackingItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this item?'**
  String get deletePackingItemTitle;

  /// No description provided for @deletePackingItemBody.
  ///
  /// In en, this message translates to:
  /// **'This removes it from the packing list.'**
  String get deletePackingItemBody;

  /// No description provided for @packingItemDeleted.
  ///
  /// In en, this message translates to:
  /// **'Item deleted.'**
  String get packingItemDeleted;

  /// No description provided for @packingItemFormAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get packingItemFormAddTitle;

  /// No description provided for @packingItemFormEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get packingItemFormEditTitle;

  /// No description provided for @packingItemFormLabel.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get packingItemFormLabel;

  /// No description provided for @packingItemFormCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get packingItemFormCategory;

  /// No description provided for @errPackingLabelRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for this item'**
  String get errPackingLabelRequired;

  /// No description provided for @packingApplyTemplateAction.
  ///
  /// In en, this message translates to:
  /// **'Apply template…'**
  String get packingApplyTemplateAction;

  /// No description provided for @packingManageTemplatesAction.
  ///
  /// In en, this message translates to:
  /// **'Manage templates…'**
  String get packingManageTemplatesAction;

  /// No description provided for @packingApplyTemplateEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved templates yet — create one from Manage templates.'**
  String get packingApplyTemplateEmpty;

  /// No description provided for @packingApplyTemplateApplied.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Added 1 item from {name}} other{Added {count} items from {name}}}'**
  String packingApplyTemplateApplied(int count, String name);

  /// No description provided for @packingApplyTemplateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t apply this template. Try again.'**
  String get packingApplyTemplateFailed;

  /// No description provided for @packingTemplatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Packing templates'**
  String get packingTemplatesTitle;

  /// No description provided for @packingTemplatesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No templates yet'**
  String get packingTemplatesEmptyTitle;

  /// No description provided for @packingTemplatesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Build a reusable list once, then apply it to any trip.'**
  String get packingTemplatesEmptyBody;

  /// No description provided for @packingTemplatesEmptyCta.
  ///
  /// In en, this message translates to:
  /// **'New template'**
  String get packingTemplatesEmptyCta;

  /// No description provided for @newTemplateDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'New template'**
  String get newTemplateDialogTitle;

  /// No description provided for @renameTemplateDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename template'**
  String get renameTemplateDialogTitle;

  /// No description provided for @templateNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Template name'**
  String get templateNameLabel;

  /// No description provided for @errTemplateNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for this template'**
  String get errTemplateNameRequired;

  /// No description provided for @deleteTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this template?'**
  String get deleteTemplateTitle;

  /// No description provided for @deleteTemplateBody.
  ///
  /// In en, this message translates to:
  /// **'This only removes the template — trips that already used it keep their packing list.'**
  String get deleteTemplateBody;

  /// No description provided for @templateDeleted.
  ///
  /// In en, this message translates to:
  /// **'Template deleted.'**
  String get templateDeleted;

  /// No description provided for @templateItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 item} other{{count} items}}'**
  String templateItemCount(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'he':
      return AppLocalizationsHe();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
