import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/mono_text.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../l10n/app_localizations.dart';
import '../data/geocoding_service.dart';
import '../data/place_candidate_resolver.dart';
import 'place_providers.dart';

// Re-exported so callers of [PlaceCandidateReviewScreen.open] (its return
// type is `Future<ResolvedPlaceCandidate?>`) don't need a separate import
// of the data-layer file just to name the type.
export '../data/place_candidate_resolver.dart' show ResolvedPlaceCandidate;

/// Resolves an OCR'd candidate name via Wikipedia-then-Places and shows
/// it for confirmation before anything is saved — this is the "only if I
/// decide to add" decision point from the design spec (§4 step 3).
class PlaceCandidateReviewScreen extends ConsumerStatefulWidget {
  const PlaceCandidateReviewScreen({super.key, required this.candidateName});

  final String candidateName;

  static Future<ResolvedPlaceCandidate?> open(
    BuildContext context, {
    required String candidateName,
  }) {
    return Navigator.of(context, rootNavigator: true)
        .push<ResolvedPlaceCandidate>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) =>
            PlaceCandidateReviewScreen(candidateName: candidateName),
      ),
    );
  }

  @override
  ConsumerState<PlaceCandidateReviewScreen> createState() =>
      _PlaceCandidateReviewScreenState();
}

class _PlaceCandidateReviewScreenState
    extends ConsumerState<PlaceCandidateReviewScreen> {
  ResolvedPlaceCandidate? _candidate;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final result = await resolvePlaceCandidate(
      wikipedia: ref.read(placeLocationSummaryFetcherProvider),
      geocoder: ref.read(geocoderProvider),
      name: widget.candidateName,
    );
    if (mounted) setState(() => _candidate = result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final candidate = _candidate;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.placeCandidateReviewTitle)),
      body: candidate == null
          ? Center(child: Text(l10n.placeCandidateReviewLookingUp))
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A place name is a name — serif (CLAUDE.md hard rule
                    // 6), which is `titleLarge` in this app's TextTheme.
                    // `headlineSmall` isn't defined there and silently fell
                    // back to a Material sans default.
                    Text(
                      candidate.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (candidate.summary != null)
                      Text(candidate.summary!)
                    else
                      Text(l10n.placeCandidateReviewNoSummary),
                    const SizedBox(height: AppSpacing.sm),
                    // City/country is metadata — mono and muted, matching
                    // how `PlaceRowCard` renders the same pair.
                    if (candidate.hasLocation)
                      MonoText(
                        [candidate.city, candidate.country]
                            .where((s) => s.isNotEmpty)
                            .join(', '),
                        muted: true,
                      )
                    else
                      Text(l10n.placeCandidateReviewNoLocation),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(l10n.placeCandidateReviewCancel),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.of(context).pop(candidate),
                            child: Text(l10n.placeCandidateReviewConfirm),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
