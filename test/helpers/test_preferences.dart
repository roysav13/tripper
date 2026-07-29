import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripper/core/settings/settings_service.dart';
import 'package:tripper/core/sharing/share_intent_service.dart';

/// The share-intent plugin has no implementation in the test VM. Any test
/// that builds the full app must stub the stream out.
Override testSharesOverride() => incomingSharesProvider
    .overrideWith((ref) => const Stream<IncomingShare>.empty());

/// Widget tests that build the app (or any screen reading settings) need a
/// real SharedPreferences instance; the mock backend keeps it in memory.
Future<Override> testPreferencesOverride([
  Map<String, Object> values = const {},
]) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  return sharedPreferencesProvider.overrideWithValue(prefs);
}
