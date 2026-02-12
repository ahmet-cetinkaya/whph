import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';
import 'package:whph/shared/services/background_translation_service.dart';
import 'package:whph/shared/state/app_startup_error_state.dart';

/// Screen displayed when an error occurs during app startup
class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({
    super.key,
    required this.errorState,
    required this.translationService,
    this.onReportError,
  });

  final AppStartupErrorState errorState;
  final BackgroundTranslationService translationService;
  final VoidCallback? onReportError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: _StartupErrorContent(
        errorState: errorState,
        translationService: translationService,
        onReportError: onReportError,
      ),
    );
  }
}

/// Internal content widget for the startup error screen
class _StartupErrorContent extends StatelessWidget {
  const _StartupErrorContent({
    required this.errorState,
    required this.translationService,
    this.onReportError,
  });

  final AppStartupErrorState errorState;
  final BackgroundTranslationService translationService;
  final VoidCallback? onReportError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surface0,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.sizeLarge),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sad face icon
                  Text(":(",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: AppTheme.iconSize3XLarge,
                          color: AppTheme.primaryColor)),

                  const SizedBox(height: AppTheme.sizeLarge),

                  // Error title
                  Text(
                    translationService.translate(SharedTranslationKeys.startupErrorTitle),
                    style: AppTheme.headlineMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.sizeMedium),

                  // Error description
                  Text(translationService.translate(SharedTranslationKeys.startupErrorDescription),
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.secondaryTextColor,
                      )),
                  const SizedBox(height: AppTheme.sizeXLarge),

                  // Error details card
                  Container(
                    padding: const EdgeInsets.all(AppTheme.sizeMedium),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                      border: Border.all(
                        color: AppTheme.errorColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: AppTheme.iconSizeSmall,
                              color: AppTheme.errorColor,
                            ),
                            const SizedBox(width: AppTheme.sizeSmall),
                            Expanded(
                              child: Text(
                                translationService.translate(SharedTranslationKeys.startupErrorDetailsTitle),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.errorColor,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _copyErrorToClipboard(context),
                              icon: const Icon(
                                Icons.copy,
                                size: AppTheme.iconSizeSmall,
                              ),
                              color: AppTheme.errorColor,
                              tooltip: translationService.translate(SharedTranslationKeys.copyErrorButton),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.sizeSmall),
                        Text(
                          errorState.getFormattedErrorMessage(),
                          style: AppTheme.bodySmall.copyWith(
                            fontFamily: 'monospace',
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.sizeXLarge),

                  // Action button
                  if (onReportError != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onReportError,
                        icon: const Icon(Icons.bug_report),
                        label: Text(
                          translationService.translate(SharedTranslationKeys.reportIssueButton),
                          style: TextStyle(color: AppTheme.darkTextColor, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: AppTheme.darkTextColor,
                          padding: const EdgeInsets.all(AppTheme.sizeMedium),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Copies error details to clipboard
  Future<void> _copyErrorToClipboard(BuildContext context) async {
    final errorDetails = errorState.getDetailedErrorInfo();
    await Clipboard.setData(ClipboardData(text: errorDetails));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            translationService.translate(SharedTranslationKeys.copiedToClipboard),
            style: TextStyle(color: AppTheme.darkTextColor),
          ),
          backgroundColor: AppTheme.successColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
