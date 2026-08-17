// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get appTitle => 'Tripper';

  @override
  String get tabTrips => 'טיולים';

  @override
  String get tabVault => 'כספת';

  @override
  String get tabPlaces => 'מקומות';

  @override
  String get tripsEmptyTitle => 'תכנן את הטיול הראשון שלך';

  @override
  String get tripsEmptyBody => 'תאריכים, מסמכים ומקומות — הכול בכיס אחד.';

  @override
  String get tripsEmptyCta => 'צור טיול';

  @override
  String get backupReminderBody =>
      'הטיולים שלך שמורים רק במכשיר הזה. גבה אותם כדי שטלפון שאבד לא יהפוך לטיול שאבד.';

  @override
  String get backupReminderCta => 'גבה עכשיו';

  @override
  String get errorStateTitle => 'משהו השתבש בטעינה';

  @override
  String get errorStateBody => 'הנתונים שלך עדיין בטוחים במכשיר הזה. נסה שוב.';

  @override
  String get errorStateRetry => 'נסה שוב';

  @override
  String get vaultEmptyTitle => 'המסמכים שלך, זמינים בכל מקום';

  @override
  String get vaultEmptyBody => 'דרכון, כרטיסים, הזמנות — נשמרים רק במכשיר הזה.';

  @override
  String get vaultEmptyCta => 'הוסף מסמך';

  @override
  String get placesEmptyTitle => 'לאן בפעם הבאה?';

  @override
  String get placesEmptyBody =>
      'נהל רשימה של מקומות שתרצה לראות, ואלה שכבר ביקרת בהם.';

  @override
  String get placesEmptyCta => 'הוסף מקום';

  @override
  String get comingSoon => 'בקרוב';

  @override
  String get sectionActive => 'פעילים כעת';

  @override
  String get sectionUpcoming => 'קרובים';

  @override
  String get sectionPlanned => 'מתוכננים';

  @override
  String get sectionPast => 'עברו';

  @override
  String get sectionArchived => 'בארכיון';

  @override
  String get datesTbd => 'תאריכים טרם נקבעו';

  @override
  String fromDate(String date) {
    return 'החל מ-$date';
  }

  @override
  String tripDayOpen(int n) {
    return 'יום $n';
  }

  @override
  String get themeToggleTooltip => 'החלף ערכת נושא';

  @override
  String tripDayCount(int n, int m) {
    return 'יום $n מתוך $m';
  }

  @override
  String get tripFormTitleNew => 'טיול חדש';

  @override
  String get tripFormTitleEdit => 'עריכת טיול';

  @override
  String get tripFormName => 'שם הטיול';

  @override
  String get tripFormDestinations => 'יעדים';

  @override
  String get tripFormAddDestination => 'הוסף יעד';

  @override
  String get tripFormAddDestinationHint => 'קראבי';

  @override
  String get tripFormDates => 'תאריכים';

  @override
  String get tripFormDatesHint =>
      'אופציונלי — השאר ריק בשלב התכנון, או הזן רק תאריך התחלה לטיולים בכיוון אחד.';

  @override
  String get tripFormStartDate => 'תאריך התחלה';

  @override
  String get tripFormEndDate => 'תאריך סיום';

  @override
  String get tripFormCoverPhoto => 'תמונת שער';

  @override
  String get tripFormCoverPhotoTooLarge =>
      'התמונה גדולה מדי — נסו תמונה קטנה יותר.';

  @override
  String get errEndWithoutStart => 'קבע קודם תאריך התחלה';

  @override
  String get save => 'שמירה';

  @override
  String get cancel => 'ביטול';

  @override
  String get errNameRequired => 'תן שם לטיול';

  @override
  String get errNoDestination => 'הוסף יעד אחד לפחות';

  @override
  String get errDatesRequired => 'בחר תאריכי התחלה וסיום תקינים';

  @override
  String get menuEdit => 'עריכה';

  @override
  String get menuArchive => 'העבר לארכיון';

  @override
  String get menuUnarchive => 'הוצא מהארכיון';

  @override
  String get menuDelete => 'מחיקה';

  @override
  String get deleteTripTitle => 'למחוק את הטיול הזה?';

  @override
  String get deleteTripBody =>
      'הטיול יימחק. מסמכים ומקומות המקושרים אליו יישמרו.';

  @override
  String get tabDocuments => 'מסמכים';

  @override
  String get tabPlacesInTrip => 'מקומות';

  @override
  String get tabExpenses => 'הוצאות';

  @override
  String get expensesEmptyTitle => 'עקוב אחרי העלות של הטיול';

  @override
  String get expensesEmptyBody =>
      'הוסף את ההוצאות שלך תוך כדי הטיול — הסכום הכולל ופילוח לפי קטגוריות יצטברו כאן.';

  @override
  String get expensesEmptyCta => 'הוסף הוצאה';

  @override
  String get expensesTotal => 'סך הכול';

  @override
  String expensesConvertedTotal(String amount, String currency) {
    return '≈ $amount $currency';
  }

  @override
  String expensesConversionPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count הוצאות עדיין לא הומרו',
      many: '$count הוצאות עדיין לא הומרו',
      two: 'שתי הוצאות עדיין לא הומרו',
      one: '1 הוצאה עדיין לא הומרה',
    );
    return '$_temp0';
  }

  @override
  String get expensesConversionOffHint =>
      'הגדר מטבע בית בהגדרות כדי לראות סכום כולל אחד.';

  @override
  String expensesRatesAsOf(String date) {
    return 'שערים מתאריך $date';
  }

  @override
  String expenseGroupWeekOf(String date) {
    return 'שבוע $date';
  }

  @override
  String get settingsHomeCurrency => 'מטבע בית';

  @override
  String get settingsHomeCurrencyHint =>
      'ממיר את סך ההוצאות בטיול, גם אם הן במטבעות שונים, לסכום אחד. נדרש חיבור לאינטרנט בפעם הראשונה בלבד; הסכומים המומרים נשמרים לאחר מכן ופועלים גם ללא חיבור. השאר ריק כדי להציג כל מטבע בנפרד.';

  @override
  String get settingsHomeCurrencyOff => 'כבוי';

  @override
  String get currencyPickerSearch => 'חיפוש מטבע';

  @override
  String get currencyPickerOffHint => 'הצג כל מטבע בנפרד, ללא המרה.';

  @override
  String get currencyPickerNoMatch => 'לא נמצא מטבע מתאים.';

  @override
  String get expenseFormTitle => 'הוספת הוצאה';

  @override
  String get expenseFormEditTitle => 'עריכת הוצאה';

  @override
  String get expenseFormAmount => 'סכום';

  @override
  String get expenseFormCurrency => 'מטבע';

  @override
  String get expenseFormNotes => 'הערה (אופציונלי)';

  @override
  String get expenseFormDate => 'תאריך';

  @override
  String get errAmountRequired => 'הזן סכום, לדוגמה 12.30';

  @override
  String get errCurrencyRequired => 'השתמש בקוד בן 3 אותיות, למשל ILS';

  @override
  String get expenseDeleted => 'ההוצאה נמחקה.';

  @override
  String get catFood => 'אוכל';

  @override
  String get catActivities => 'פעילויות';

  @override
  String get catShopping => 'קניות';

  @override
  String get tripDocsEmptyTitle => 'אין מסמכים מקושרים';

  @override
  String get tripDocsEmptyBody => 'טיסות, לינה וכרטיסים לטיול הזה יופיעו כאן.';

  @override
  String get vaultPinnedSection => 'מוצמדים · גישה מהירה';

  @override
  String get vaultAllSection => 'כל המסמכים';

  @override
  String get vaultSortCreated => 'נוצר';

  @override
  String get vaultSortRelevant => 'תאריך רלוונטי';

  @override
  String get vaultFilterCategorySection => 'קטגוריה';

  @override
  String vaultFilterShowResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'הצג $count מסמכים',
      one: 'הצג מסמך אחד',
    );
    return '$_temp0';
  }

  @override
  String get catPassport => 'דרכון / תעודת זהות';

  @override
  String get catVisa => 'ויזה';

  @override
  String get catFlight => 'טיסה';

  @override
  String get catStay => 'לינה';

  @override
  String get catInsurance => 'ביטוח';

  @override
  String get catTransport => 'תחבורה';

  @override
  String get catOther => 'אחר';

  @override
  String get manualRecord => 'ידני';

  @override
  String expiryShort(String date) {
    return 'תפוגה $date';
  }

  @override
  String get docFormTitle => 'הוספת מסמך';

  @override
  String get docFormName => 'שם המסמך';

  @override
  String get docFormAttachFile => 'צירוף קובץ';

  @override
  String get docFormExpiry => 'תאריך תפוגה';

  @override
  String get docFormGlobal => 'שמור בכספת הכללית';

  @override
  String get docFormGlobalHint =>
      'למסמכים שרלוונטיים גם מעבר לטיול — דרכון, רישיון, ביטוח.';

  @override
  String get fieldFlightNumber => 'מספר טיסה';

  @override
  String get fieldConfirmationCode => 'קוד אישור';

  @override
  String get docFormDepartureTime => 'שעת המראה';

  @override
  String get docFormDepartureTimeHint =>
      'מפעיל את התזכורת לפתיחת הצ\'ק-אין (M5.3) — אופציונלי.';

  @override
  String get docOcrPrefilled =>
      'מולא אוטומטית מהתמונה — כדאי לבדוק שוב לפני השמירה.';

  @override
  String docTitleFlight(String number) {
    return 'טיסה $number';
  }

  @override
  String get fieldBookingRef => 'מספר הזמנה';

  @override
  String get fieldDocumentNumber => 'מספר מסמך';

  @override
  String get docActionOpen => 'פתיחה';

  @override
  String get showCodeAction => 'הצג בשער';

  @override
  String get showCodeFileMissing =>
      'הקובץ של המסמך הזה חסר. צרף אותו מחדש מהכספת.';

  @override
  String get showCodePdfFallback =>
      'לא ניתן להציג את קובץ ה-PDF כאן. פתח אותו באפליקציית צפייה אחרת.';

  @override
  String get docActionPin => 'הצמד לגישה מהירה';

  @override
  String get docActionUnpin => 'ביטול הצמדה';

  @override
  String get docActionLink => 'קשר לטיולים';

  @override
  String get pinLimitReached =>
      'ניתן להצמיד עד 4 מסמכים. בטל הצמדה של אחד קודם.';

  @override
  String get noTripsToLink => 'עדיין אין טיולים — צור אחד קודם.';

  @override
  String get docLinksUpdated => 'קישורי הטיולים עודכנו.';

  @override
  String get docLinksUpdateFailed =>
      'לא ניתן היה לעדכן את קישורי הטיולים. נסה שוב.';

  @override
  String get vaultLockedTitle => 'הכספת נעולה';

  @override
  String get vaultLockedBody => 'המסמכים שלך מוגנים באמצעות נעילת המכשיר.';

  @override
  String get unlockCta => 'שחרור נעילה';

  @override
  String get unlockReason => 'שחרר את נעילת כספת המסמכים';

  @override
  String get unlockSettingsReason => 'שחרר את נעילת ההגדרות של Tripper';

  @override
  String get settingsLockedTitle => 'ההגדרות נעולות';

  @override
  String get settingsLockedBody =>
      'אפשרויות הגיבוי והאבטחה מוגנות באמצעות נעילת המכשיר.';

  @override
  String get deleteDocTitle => 'למחוק את המסמך הזה?';

  @override
  String get deleteDocBody => 'המסמך והקובץ שלו יימחקו מהמכשיר הזה.';

  @override
  String expiryTripWarning(String title) {
    return 'המסמך $title פג בסמוך מדי לסיום הטיול הזה. בדוק את דרישות הכניסה.';
  }

  @override
  String get tripPlacesEmptyTitle => 'עדיין אין מקומות';

  @override
  String get tripPlacesEmptyBody => 'עקוב אחרי מה שתרצה לראות בטיול הזה.';

  @override
  String get placesWantSection => 'רוצה לבקר';

  @override
  String get placesBeenSection => 'כבר ביקרתי';

  @override
  String get placeMarkVisited => 'סמן כמבוקר';

  @override
  String get placeViewOnMap => 'הצג במפה';

  @override
  String get placeOpenInGoogleMaps => 'פתח ב-Google Maps';

  @override
  String get placeOpenMapsFailed => 'לא ניתן היה לפתוח את Google Maps.';

  @override
  String get placeUnvisit => 'העבר בחזרה לרשימת המשאלות';

  @override
  String get placeSummaryShow => 'הצג תקציר';

  @override
  String get placeSummaryHide => 'הסתר תקציר';

  @override
  String visitedOn(String date) {
    return 'ביקרת ב-$date';
  }

  @override
  String get placeFormTitle => 'הוספת מקום';

  @override
  String get placeFormName => 'שם המקום';

  @override
  String get placeFormCity => 'עיר';

  @override
  String get placeFormCountry => 'מדינה';

  @override
  String get placeFormTrip => 'קשר לטיול';

  @override
  String get placeFormDescription => 'תיאור';

  @override
  String get catHotel => 'מלון';

  @override
  String get catRestaurant => 'מסעדה';

  @override
  String get catCoffeeShop => 'בית קפה';

  @override
  String get catBar => 'בר';

  @override
  String get catAttraction => 'אטרקציה';

  @override
  String get catMuseum => 'מוזיאון';

  @override
  String get catAmusementPark => 'פארק שעשועים';

  @override
  String get catTrek => 'טרק';

  @override
  String get catBeach => 'חוף';

  @override
  String get catNature => 'טבע';

  @override
  String get mapViewToggle => 'תצוגת מפה';

  @override
  String get listViewToggle => 'תצוגת רשימה';

  @override
  String get filterClearAll => 'נקה סינון';

  @override
  String get filterSortButtonTooltip => 'מיון וסינון';

  @override
  String get filterSortSheetTitle => 'מיון וסינון';

  @override
  String get filterSortSortSection => 'מיון';

  @override
  String get sortAToZ => 'א–ת';

  @override
  String get sortZToA => 'ת–א';

  @override
  String get sortOldestFirst => 'הישן ביותר';

  @override
  String get sortNewestFirst => 'החדש ביותר';

  @override
  String get sortNearestFirst => 'הקרוב ביותר';

  @override
  String get sortFarthestFirst => 'הרחוק ביותר';

  @override
  String get placesSortRecommended => 'מומלץ';

  @override
  String get placesSortName => 'שם';

  @override
  String get placesSortVisitedDate => 'תאריך ביקור';

  @override
  String get placesSortDistance => 'מרחק';

  @override
  String get placesSortDistanceFetching => 'מאתר מיקום…';

  @override
  String get placesSortDistanceServiceDisabled =>
      'הפעל שירותי מיקום כדי למיין לפי מרחק';

  @override
  String get placesSortDistancePermissionDenied =>
      'אפשר גישה למיקום כדי למיין לפי מרחק';

  @override
  String get placesSortDistanceError => 'לא ניתן היה לאתר את המיקום';

  @override
  String get placesSortDistanceRetry => 'נסה שוב';

  @override
  String get placesSortDistanceOpenSettings => 'הגדרות';

  @override
  String placeDistanceKmAway(String km) {
    return 'במרחק $km ק\"מ';
  }

  @override
  String placeDistanceMetersAway(int m) {
    return 'במרחק $m מ\'';
  }

  @override
  String get placesFilterButton => 'סינון';

  @override
  String get placesFilterSheetTitle => 'מסננים';

  @override
  String get placesFilterEmptyTitle => 'אין מקומות מתאימים';

  @override
  String get placesFilterEmptyBody =>
      'נסו קטגוריה או מדינה אחרת, או נקו את הסינון כדי לראות הכול מחדש.';

  @override
  String get placesFilterEmptyCta => 'נקה סינון';

  @override
  String get placesFilterCategorySection => 'קטגוריה';

  @override
  String get placesFilterCountrySection => 'מדינה';

  @override
  String get placesFilterSearchCountry => 'חיפוש מדינות';

  @override
  String get placesFilterSearchNoResults => 'אין מדינות מתאימות';

  @override
  String placesFilterShowResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'הצג $count מקומות',
      one: 'הצג מקום אחד',
    );
    return '$_temp0';
  }

  @override
  String get journalGlobeLoading => 'טוען את הגלובוס';

  @override
  String journalGlobeClusterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count רשומות',
      many: '$count רשומות',
      two: 'שתי רשומות',
      one: '1 רשומה',
    );
    return '$_temp0';
  }

  @override
  String get pickOnMap => 'בחר במפה';

  @override
  String get pickOnMapTitle => 'הצב נעץ';

  @override
  String get pickOnMapHint =>
      'חפש למעלה, או לחץ לחיצה ארוכה על המפה כדי להציב את הנעץ';

  @override
  String get mapSearchHint => 'חפש מקום';

  @override
  String get mapSearchNoResults => 'אין תוצאות — נסה איות אחר.';

  @override
  String get mapSearchOffline =>
      'החיפוש דורש חיבור לאינטרנט. לחץ לחיצה ארוכה על המפה במקום זאת.';

  @override
  String get mapLayersButton => 'שכבות מפה';

  @override
  String get mapLayerNormal => 'ברירת מחדל';

  @override
  String get mapLayerSatellite => 'לוויין';

  @override
  String get mapLayerTerrain => 'פני שטח';

  @override
  String addWithoutLocation(String query) {
    return 'הוסף את \"$query\" ללא מיקום';
  }

  @override
  String get noLocationChip => 'ללא מיקום';

  @override
  String get editPlaceTitle => 'עריכת מקום';

  @override
  String get deletePlaceTitle => 'למחוק את המקום הזה?';

  @override
  String get deletePlaceBody => 'המקום יוסר מהרשימות שלך ומהמפה.';

  @override
  String get deleteExpenseTitle => 'למחוק את ההוצאה הזו?';

  @override
  String get deleteExpenseBody => 'פעולה זו תסיר אותה מהסכום הכולל של הטיול.';

  @override
  String get tripCompleteTitle => 'הטיול הסתיים — לעדכן את המפה?';

  @override
  String tripCompleteBody(String trip) {
    return 'הטיול $trip הסתיים. סמן את המקומות שהגעת אליהם כמבוקרים:';
  }

  @override
  String get tripCompleteConfirm => 'סמן כמבוקר';

  @override
  String get tripCompleteSkip => 'לא עכשיו';

  @override
  String get settingsTitle => 'הגדרות';

  @override
  String get settingsAppearance => 'מראה';

  @override
  String get themeLight => 'בהיר';

  @override
  String get themeDark => 'כהה';

  @override
  String get themeSystem => 'מערכת';

  @override
  String get settingsLanguage => 'שפה';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHebrew => 'עברית';

  @override
  String get settingsSecurity => 'אבטחה';

  @override
  String get settingsVaultLock => 'נעילת הכספת';

  @override
  String get settingsVaultLockHint => 'בקש טביעת אצבע לפני פתיחת מסמכים.';

  @override
  String get settingsBackup => 'גיבוי';

  @override
  String get settingsBackupHint =>
      'הכול שמור רק במכשיר הזה. ייצא גיבוי שתוכל לשחזר אחרי התקנה מחדש או במכשיר חדש.';

  @override
  String get settingsExport => 'ייצוא גיבוי';

  @override
  String get settingsExportShareText => 'גיבוי Tripper';

  @override
  String get settingsExportFailed => 'לא ניתן היה ליצור את הגיבוי. נסה שוב.';

  @override
  String get settingsImport => 'שחזור גיבוי';

  @override
  String get settingsImportTitle => 'לשחזר מגיבוי?';

  @override
  String get settingsImportWarning =>
      'פעולה זו תחליף כל טיול, מסמך ומקום במכשיר הזה בתוכן מהגיבוי.';

  @override
  String get settingsImportDone =>
      'הגיבוי שוחזר. הפעל מחדש את Tripper כדי לראות אותו.';

  @override
  String get settingsImportCorrupt => 'הקובץ הזה אינו גיבוי תקין של Tripper.';

  @override
  String get settingsImportTooNew =>
      'הגיבוי הזה נוצר בגרסה חדשה יותר של Tripper.';

  @override
  String get settingsNotifications => 'התראות';

  @override
  String get settingsExpiryNoticeHint =>
      'כמה זמן לפני תאריך התפוגה של מסמך הוא נחשב \'מתקרב\'.';

  @override
  String get settingsExpiryNoticeOff => 'כבוי';

  @override
  String get settingsNearbyPlaces => 'מקומות בקרבת מקום';

  @override
  String get settingsNearbyPlacesHint =>
      'מצא מקומות מדורגים גבוה בקרבתך או ליד מקום שמור, ישירות מלשונית המקומות.';

  @override
  String settingsNearbyPlacesCallCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count חיפושים בהתקנה זו',
      one: 'חיפוש אחד בהתקנה זו',
    );
    return '$_temp0';
  }

  @override
  String get settingsNearbyPlacesNoKey => 'דורש הגדרת מפתח Maps API';

  @override
  String docExpiryNotificationTitle(String title) {
    return 'המסמך $title עומד לפוג בקרוב';
  }

  @override
  String docExpiryNotificationBody(String date) {
    return 'התוקף יפוג בתאריך $date.';
  }

  @override
  String tripCountdownNotificationTitle(String name) {
    return 'הטיול $name מתחיל בקרוב';
  }

  @override
  String tripCountdownNotificationBodyClear(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'מתחיל בעוד $days ימים',
      many: 'מתחיל בעוד $days ימים',
      two: 'מתחיל בעוד יומיים',
      one: 'מתחיל בעוד יום',
    );
    return '$_temp0 — הכול בסדר.';
  }

  @override
  String tripCountdownNotificationBodyWithIssues(int days, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'מתחיל בעוד $days ימים',
      many: 'מתחיל בעוד $days ימים',
      two: 'מתחיל בעוד יומיים',
      one: 'מתחיל בעוד יום',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count מסמכים דורשים תשומת לב',
      many: '$count מסמכים דורשים תשומת לב',
      two: 'שני מסמכים דורשים תשומת לב',
      one: '1 מסמך דורש תשומת לב',
    );
    return '$_temp0 — $_temp1.';
  }

  @override
  String checkInNotificationTitle(String title) {
    return 'הצ\'ק-אין נפתח עבור $title';
  }

  @override
  String get checkInNotificationBody =>
      'בדרך כלל הצ\'ק-אין נפתח 24 שעות לפני ההמראה. חברות התעופה משנות את הטווח הזה בין 24 ל-48 שעות, אז כדאי לבדוק מול החברה שלך.';

  @override
  String get placeFormNoTrip => 'ללא טיול';

  @override
  String tripPlacesProgress(int visited, int total) {
    return 'ביקרת ב-$visited מתוך $total';
  }

  @override
  String get tabJournal => 'יומן';

  @override
  String get journalEmptyTitle => 'עדיין אין רשומות ביומן';

  @override
  String get journalEmptyBody => 'רשום הערה מהדרך — לאן הלכת ומה קרה.';

  @override
  String get journalAddEntryCta => 'הוסף רשומה';

  @override
  String get journalEntryFormTitle => 'רשומה חדשה';

  @override
  String get journalEntryFormEditTitle => 'עריכת רשומה';

  @override
  String get journalFieldSummary => 'מה קרה?';

  @override
  String get journalAddPhoto => 'הוסף תמונה';

  @override
  String get journalPhotoSourceCamera => 'מצלמה';

  @override
  String get journalPhotoSourceGallery => 'גלריה';

  @override
  String get journalRemovePhoto => 'הסר תמונה';

  @override
  String get journalAddLocation => 'הוסף מיקום';

  @override
  String get journalClearLocation => 'נקה מיקום';

  @override
  String get journalDeleteEntryTitle => 'למחוק את הרשומה הזו?';

  @override
  String get journalDeleteEntryBody =>
      'פעולה זו תמחק את הטקסט ואת כל התמונות. לא ניתן לבטל פעולה זו.';

  @override
  String get journalMapLocationHint => 'רשומות ללא מיקום לא יופיעו כאן.';

  @override
  String get journalUntitledEntry => 'טרם נכתב';

  @override
  String journalStatsLine(int entries, int places) {
    return '$entries רשומות · $places מקומות שביקרת בהם';
  }

  @override
  String get journalPickNow => 'עכשיו';

  @override
  String get journalPickToday => 'היום';

  @override
  String get journalPickYesterday => 'אתמול';

  @override
  String get journalTripLocations => 'המיקומים של הטיול הזה';

  @override
  String get journalNewLocation => 'מיקום חדש';
}
