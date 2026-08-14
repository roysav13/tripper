import 'package:flutter_test/flutter_test.dart';
import 'package:tripper/features/trips/domain/trip.dart';
import 'package:tripper/features/vault/domain/document.dart';
import 'package:tripper/features/vault/domain/expiry_checker.dart';

Document _doc({DateTime? expiry}) => Document(
      id: 'd1',
      title: 'Passport',
      category: DocumentCategory.passportId,
      createdAt: DateTime(2026, 7, 19),
      expiryDate: expiry,
    );

void main() {
  final today = DateTime(2026, 7, 19);

  group('isExpired', () {
    test('no expiry date is never expired', () {
      expect(ExpiryChecker.isExpired(_doc(), today), isFalse);
    });

    test('yesterday is expired, today is not', () {
      expect(
        ExpiryChecker.isExpired(_doc(expiry: DateTime(2026, 7, 18)), today),
        isTrue,
      );
      expect(
        ExpiryChecker.isExpired(_doc(expiry: DateTime(2026, 7, 19)), today),
        isFalse,
      );
    });
  });

  group('isExpiringSoon (90-day buffer)', () {
    test('day 90 is soon, day 91 is not', () {
      expect(
        ExpiryChecker.isExpiringSoon(
          _doc(expiry: DateTime(2026, 7, 19 + 90)),
          today,
        ),
        isTrue,
      );
      expect(
        ExpiryChecker.isExpiringSoon(
          _doc(expiry: DateTime(2026, 7, 19 + 91)),
          today,
        ),
        isFalse,
      );
    });

    test('already expired is not "soon"', () {
      expect(
        ExpiryChecker.isExpiringSoon(
          _doc(expiry: DateTime(2026, 1, 1)),
          today,
        ),
        isFalse,
      );
    });
  });

  group('isExpiringSoon with a custom noticeDays (M5, 2026-07-23 setting)', () {
    test('respects a shorter configured window', () {
      final doc = _doc(expiry: DateTime(2026, 7, 19 + 10));
      expect(
        ExpiryChecker.isExpiringSoon(doc, today, noticeDays: 30),
        isTrue,
      );
      expect(
        ExpiryChecker.isExpiringSoon(doc, today, noticeDays: 5),
        isFalse,
      );
    });

    test('noticeDays: 0 means never "soon" (only isExpired matters)', () {
      final doc = _doc(expiry: today); // expires today — not yet expired
      expect(
        ExpiryChecker.isExpiringSoon(doc, today, noticeDays: 0),
        isFalse,
      );
    });
  });

  group('needsAttention', () {
    test('true when expired, regardless of noticeDays', () {
      final doc = _doc(expiry: DateTime(2026, 1, 1));
      expect(ExpiryChecker.needsAttention(doc, today, noticeDays: 0), isTrue);
    });

    test('true when within a custom notice window', () {
      final doc = _doc(expiry: DateTime(2026, 7, 19 + 10));
      expect(
        ExpiryChecker.needsAttention(doc, today, noticeDays: 30),
        isTrue,
      );
    });

    test('false when outside the window and not expired', () {
      final doc = _doc(expiry: DateTime(2026, 7, 19 + 10));
      expect(
        ExpiryChecker.needsAttention(doc, today, noticeDays: 5),
        isFalse,
      );
    });
  });

  group('isRiskyForTrip', () {
    final trip = Trip(
      id: 't1',
      name: 'Rome',
      destinations: const ['Rome'],
      startDate: DateTime(2026, 10, 3),
      endDate: DateTime(2026, 10, 7),
    );

    test('expiry just inside the buffer is risky', () {
      // Calendar days (DateTime normalizes day overflow), not Duration —
      // Duration arithmetic drifts across DST transitions.
      final doc = _doc(expiry: DateTime(2026, 10, 7 + 89));
      expect(ExpiryChecker.isRiskyForTrip(doc, trip), isTrue);
    });

    test('expiry exactly at end + buffer is safe', () {
      final doc = _doc(expiry: DateTime(2026, 10, 7 + 90));
      expect(ExpiryChecker.isRiskyForTrip(doc, trip), isFalse);
    });

    test('open-ended trip falls back to start date', () {
      final openEnded = Trip(
        id: 't2',
        name: 'One way',
        destinations: const ['Lisbon'],
        startDate: DateTime(2026, 10, 3),
      );
      final doc = _doc(expiry: DateTime(2026, 11, 1));
      expect(ExpiryChecker.isRiskyForTrip(doc, openEnded), isTrue);
    });

    test('planned trip (no dates) is never risky', () {
      const planned = Trip(id: 't3', name: 'Japan', destinations: ['Tokyo']);
      final doc = _doc(expiry: DateTime(2026, 8, 1));
      expect(ExpiryChecker.isRiskyForTrip(doc, planned), isFalse);
    });

    test('document without expiry is never risky', () {
      expect(ExpiryChecker.isRiskyForTrip(_doc(), trip), isFalse);
    });
  });
}
