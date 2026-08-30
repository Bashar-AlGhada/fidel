import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'app_states.dart';

/// Generic `AsyncValue.when` renderer that replaces the per-page
/// loading/error boilerplate.
///
/// ```dart
/// AsyncValueView(
///   value: ref.watch(myProvider),
///   data: (MyData d) => Text(d.name),
///   errorTitle: 'section.x.error'.tr,
///   onRetry: () => ref.invalidate(myProvider),
/// )
/// ```
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.data,
    this.loadingMessage,
    this.errorTitle = 'Error',
    this.errorMessage,
    this.retryLabel,
    this.onRetry,
    super.key,
  });

  final AsyncValue<T> value;

  /// Builds the success UI from the resolved data.
  final Widget Function(T data) data;

  /// Optional message under the loading spinner.
  final String? loadingMessage;

  /// Error card title. Callers should pass a localized string; defaults to
  /// a neutral English fallback so the widget stays usable without GetX.
  final String? errorTitle;

  /// Optional extra detail shown under the title (defaults to the error).
  final String? errorMessage;

  /// Label for the retry button (pass a localized string).
  final String? retryLabel;

  /// Retry callback — typically `() => ref.invalidate(provider)`.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnReload: true,
      data: data,
      loading: () => AppLoadingState(message: loadingMessage),
      error: (err, _) => AppErrorState(
        title: errorTitle ?? 'Error',
        message: errorMessage ?? '$err',
        actionLabel: onRetry != null ? (retryLabel ?? 'Retry') : null,
        onAction: onRetry,
      ),
    );
  }
}
