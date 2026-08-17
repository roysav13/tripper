import 'package:tripper/core/location/location_service.dart';

/// Fake at the [LocationService] boundary (testing rules — no real GPS/
/// platform channel calls in widget tests).
class FakeLocationService implements LocationService {
  FakeLocationService(this.fix);

  LocationFix fix;
  var callCount = 0;

  @override
  Future<LocationFix> getCurrentLocation() async {
    callCount++;
    return fix;
  }
}
