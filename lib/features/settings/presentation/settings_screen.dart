import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/backup/backup_service.dart';
import '../../../core/security/vault_lock.dart';
import '../../../core/settings/settings_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_label.dart';
import '../../../features/expenses/domain/currencies.dart';
import '../../../features/expenses/presentation/currency_picker.dart';
import '../../../l10n/app_localizations.dart';

/// Presets rather than a free-typed number — matches the app's preference
/// for SegmentedButton choices over raw text input, and avoids validating
/// arbitrary integer entry for a setting where a handful of round values
/// cover every real use case. 0 = off (see DocExpiryNoticeDaysController).
const _kNoticeDayPresets = [0, 7, 30, 60, 90];

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Settings holds the lock switch and the export button (which packages
    // every document) — same gate as the vault.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    final l10n = AppLocalizations.of(context)!;
    await ref
        .read(vaultLockProvider.notifier)
        .ensureUnlocked(l10n.unlockSettingsReason);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final themeMode = ref.watch(themeModeProvider);
    final lockEnabled = ref.watch(vaultLockEnabledProvider);
    final noticeDays = ref.watch(documentExpiryNoticeDaysProvider);

    if (!ref.watch(vaultLockProvider)) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.settingsTitle)),
        body: EmptyState(
          icon: Icons.lock_outline,
          title: l10n.settingsLockedTitle,
          body: l10n.settingsLockedBody,
          ctaLabel: l10n.unlockCta,
          onCta: _unlock,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        children: [
          SectionLabel(l10n.settingsAppearance),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(l10n.themeLight),
                icon: const Icon(Icons.light_mode_outlined, size: 16),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(l10n.themeDark),
                icon: const Icon(Icons.dark_mode_outlined, size: 16),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l10n.themeSystem),
                icon: const Icon(Icons.brightness_auto_outlined, size: 16),
              ),
            ],
            selected: {themeMode},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                ref.read(themeModeProvider.notifier).set(selection.first),
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionLabel(l10n.settingsSecurity),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsVaultLock),
            subtitle: Text(
              l10n.settingsVaultLockHint,
              style: TextStyle(fontSize: 12, color: colors.inkMuted),
            ),
            value: lockEnabled,
            activeTrackColor: colors.accent,
            onChanged: (value) =>
                ref.read(vaultLockEnabledProvider.notifier).set(enabled: value),
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionLabel(l10n.settingsNotifications),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.settingsExpiryNoticeHint,
            style: TextStyle(fontSize: 13, color: colors.inkSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<int>(
            segments: [
              for (final days in _kNoticeDayPresets)
                ButtonSegment(
                  value: days,
                  // Plain Text with the mono style (not MonoText) — MonoText
                  // hardcodes its own foreground color, which would fight
                  // SegmentedButton's selected/unselected color styling.
                  label: Text(
                    days == 0 ? l10n.settingsExpiryNoticeOff : '${days}D',
                    style: AppTextStyles.mono,
                  ),
                ),
            ],
            selected: {noticeDays},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => ref
                .read(documentExpiryNoticeDaysProvider.notifier)
                .set(selection.first),
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionLabel(l10n.settingsHomeCurrency),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.settingsHomeCurrencyHint,
            style: TextStyle(fontSize: 13, color: colors.inkSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          _HomeCurrencyField(colors: colors),
          const SizedBox(height: AppSpacing.xl),
          SectionLabel(l10n.settingsBackup),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.settingsBackupHint,
            style: TextStyle(fontSize: 13, color: colors.inkSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            icon: const Icon(Icons.archive_outlined, size: 16),
            label: Text(l10n.settingsExport),
            onPressed: _busy ? null : _export,
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            icon: const Icon(Icons.settings_backup_restore, size: 16),
            label: Text(l10n.settingsImport),
            onPressed: _busy ? null : _import,
          ),
          if (_busy) ...[
            const SizedBox(height: AppSpacing.lg),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      final service = ref.read(backupServiceProvider);
      final tempDir = await getTemporaryDirectory();
      final target = p.join(tempDir.path, service.suggestedFileName());
      final file = await service.export(target);
      // Marked as soon as the archive exists, not after the share sheet
      // resolves — the export itself is the safety net; where the user
      // sends the file afterward doesn't change that.
      await ref.read(hasExportedProvider.notifier).markExported();
      if (!mounted) return;
      // System share sheet — user picks Drive, email, local storage…
      await Share.shareXFiles(
        [XFile(file.path)],
        text: l10n.settingsExportShareText,
      );
    } catch (_) {
      if (mounted) _snack(l10n.settingsExportFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsImportTitle),
        content: Text(l10n.settingsImportWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.settingsImport),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(backupServiceProvider).import(path);
      if (mounted) _snack(l10n.settingsImportDone);
    } on BackupException catch (e) {
      if (mounted) {
        _snack(
          switch (e.reason) {
            BackupFailure.corruptArchive => l10n.settingsImportCorrupt,
            BackupFailure.newerFormat ||
            BackupFailure.newerSchema =>
              l10n.settingsImportTooNew,
          },
        );
      }
    } catch (_) {
      if (mounted) _snack(l10n.settingsImportCorrupt);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}

/// Picker, not free text: a typed "NIS" (not an ISO code) or a typo
/// would be stored happily and then silently fail every rate lookup
/// forever. Choosing from the catalogue makes that unrepresentable.
class _HomeCurrencyField extends ConsumerWidget {
  const _HomeCurrencyField({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.watch(homeCurrencyProvider);
    final currency = currencyFor(selected);

    return OutlinedButton.icon(
      icon: const Icon(Icons.payments_outlined, size: 16),
      label: Text(
        currency == null
            ? l10n.settingsHomeCurrencyOff
            : '${currency.code} · ${currency.name}',
      ),
      onPressed: () async {
        final picked = await showCurrencyPicker(
          context,
          selected: selected.isEmpty ? null : selected,
          allowNone: true,
        );
        if (picked == null) return; // dismissed, not changed
        if (picked != ref.read(homeCurrencyProvider)) {
          await ref.read(homeCurrencyProvider.notifier).set(picked);
        }
      },
    );
  }
}
