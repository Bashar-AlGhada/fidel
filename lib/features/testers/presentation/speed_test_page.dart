import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/ui/app_page_scaffold.dart';
import '../../../core/ui/glass_card.dart';
import '../../../core/ui/sparkline.dart';

/// Network throughput tester built directly on [HttpClient] so the app
/// carries no extra dependencies.
///
/// Three sequential phases: latency probes (HEAD), downstream throughput
/// (streamed GET, discarded bytes), upstream throughput (random-buffer
/// POST). Every phase is cancellable and all sockets are closed on
/// dispose, so leaving mid-run never leaks connections.
enum _SpeedPhase { idle, ping, download, upload, done }

class SpeedTestPage extends StatefulWidget {
  const SpeedTestPage({super.key});

  @override
  State<SpeedTestPage> createState() => _SpeedTestPageState();
}

class _SpeedTestPageState extends State<SpeedTestPage> {
  static const _pingUrl = 'https://www.gstatic.com/generate_204';
  static const _downloadUrl = 'https://speed.cloudflare.com/__down';
  static const _uploadUrl = 'https://speed.cloudflare.com/__up';
  static const _downloadBytes = 25 * 1024 * 1024;
  static const _uploadBytes = 8 * 1024 * 1024;
  static const _downloadBudget = Duration(seconds: 15);
  static const _perRequestTimeout = Duration(seconds: 8);

  final HttpClient _client = HttpClient()
    ..connectionTimeout = _perRequestTimeout;

  _SpeedPhase _phase = _SpeedPhase.idle;
  String? _errorText;

  // Latency results (milliseconds).
  int? _pingMin;
  double? _pingAvg;
  double? _jitter;

  // Throughput results (Mbps).
  double? _downAvg;
  double? _peakDown;
  double? _upAvg;
  final List<double> _downSamples = [];

  @override
  void dispose() {
    _client.close(force: true);
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _errorText = null;
      _pingMin = null;
      _pingAvg = null;
      _jitter = null;
      _downAvg = null;
      _peakDown = null;
      _upAvg = null;
      _downSamples.clear();
      _phase = _SpeedPhase.ping;
    });

    try {
      await _runPingPhase();
      if (!mounted) return;
      setState(() => _phase = _SpeedPhase.download);
      await _runDownloadPhase();
      if (!mounted) return;
      setState(() => _phase = _SpeedPhase.upload);
      await _runUploadPhase();
      if (!mounted) return;
      setState(() => _phase = _SpeedPhase.done);
    } on SocketException catch (e) {
      _fail('speedTest.error.offline'.trParams({'detail': e.message}));
    } on TimeoutException {
      _fail('speedTest.error.timeout'.tr);
    } on HttpException catch (e) {
      _fail('speedTest.error.failed'.trParams({'detail': e.message}));
    } catch (e) {
      _fail('speedTest.error.failed'.trParams({'detail': '$e'}));
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _SpeedPhase.idle;
      _errorText = message;
    });
  }

  Future<void> _cancel() async {
    // Force-closing the client aborts in-flight sockets; recreate one so
    // the page keeps working after a cancel.
    _client.close(force: true);
    if (!mounted) return;
    setState(() => _phase = _SpeedPhase.idle);
  }

  Future<void> _runPingPhase() async {
    final samples = <int>[];
    for (var i = 0; i < 5; i++) {
      final sw = Stopwatch()..start();
      final req = await _client.headUrl(Uri.parse(_pingUrl));
      final res = await req.close().timeout(_perRequestTimeout);
      await res.drain<void>();
      sw.stop();
      samples.add(sw.elapsedMilliseconds);
    }
    samples.sort();
    var jitterSum = 0.0;
    for (var i = 1; i < samples.length; i++) {
      jitterSum += (samples[i] - samples[i - 1]).abs();
    }
    if (!mounted) return;
    setState(() {
      _pingMin = samples.first;
      _pingAvg = samples.average;
      _jitter = samples.length > 1 ? jitterSum / (samples.length - 1) : 0;
    });
  }

  Future<void> _runDownloadPhase() async {
    final uri = Uri.parse('$_downloadUrl?bytes=$_downloadBytes');
    final request = await _client.getUrl(uri);
    final response = await request.close().timeout(_downloadBudget);

    final completer = Completer<void>();
    var received = 0;
    // Clock starts as data begins flowing, not when headers arrive.
    var started = false;
    var start = DateTime.now();
    var lastSample = start;
    var lastBytes = 0;
    Timer? watchdog;

    late final StreamSubscription<List<int>> sub;
    sub = response.listen(
      (chunk) {
        if (!started) {
          started = true;
          start = DateTime.now();
          lastSample = start;
        }
        received += chunk.length;
        final now = DateTime.now();
        final sinceSample = now.difference(lastSample);
        if (sinceSample.inMilliseconds >= 300 && mounted) {
          final seconds = sinceSample.inMilliseconds / 1000;
          final mbps = ((received - lastBytes) * 8) / seconds / 1e6;
          setState(() {
            _downSamples.add(mbps);
            _peakDown =
                (_peakDown == null) ? mbps : math.max(_peakDown!, mbps);
          });
          lastSample = now;
          lastBytes = received;
        }
        if (now.difference(start).compareTo(_downloadBudget) >= 0) {
          sub.cancel();
          if (!completer.isCompleted) completer.complete();
        }
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
      onError: (Object e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      cancelOnError: true,
    );

    // Hard budget watchdog: abort the socket when time expires even if
    // the server trickles bytes forever.
    watchdog = Timer(_downloadBudget, () {
      sub.cancel();
      if (!completer.isCompleted) completer.complete();
    });

    try {
      await completer.future;
    } finally {
      watchdog.cancel();
    }

    final elapsed = DateTime.now().difference(start);
    if (started && elapsed.inMilliseconds > 200 && mounted) {
      setState(() {
        _downAvg = (received * 8) / (elapsed.inMilliseconds / 1000) / 1e6;
        _peakDown ??= _downAvg;
      });
    }
  }

  Future<void> _runUploadPhase() async {
    final rng = math.Random();
    final Uint8List payload = Uint8List(_uploadBytes);
    for (var i = 0; i < payload.length; i += 4096) {
      final end = math.min(i + 4096, payload.length);
      payload.setRange(i, end, List<int>.generate(end - i, (_) => rng.nextInt(256)));
    }

    final request = await _client.postUrl(Uri.parse(_uploadUrl));
    request.headers.contentLength = payload.length;
    request.add(payload);
    final sw = Stopwatch()..start();
    final response = await request.close().timeout(_downloadBudget);
    await response.drain<void>();
    sw.stop();

    if (sw.elapsedMilliseconds > 200 && mounted) {
      setState(() {
        _upAvg =
            (payload.length * 8) / (sw.elapsedMilliseconds / 1000) / 1e6;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AppPageScaffold(
      title: 'testers.speedTest'.tr,
      children: [
        _buildMain(context),
        SizedBox(height: tokens.space2),
        Text('speedTest.disclaimer'.tr, style: AppText.muted(context)),
      ],
    );
  }

  Widget _buildMain(BuildContext context) {
    switch (_phase) {
      case _SpeedPhase.idle when _errorText != null:
        return GlassCard(
          padding: EdgeInsets.all(context.tokens.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.wifi_off_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.error,
              ),
              SizedBox(height: context.tokens.space2),
              Text(_errorText!, textAlign: TextAlign.center),
              SizedBox(height: context.tokens.space3),
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.refresh),
                label: Text('action.retry'.tr),
              ),
            ],
          ),
        );
      case _SpeedPhase.idle:
      case _SpeedPhase.done:
        return _ResultsCard(
          phase: _phase,
          pingMin: _pingMin,
          pingAvg: _pingAvg,
          jitter: _jitter,
          downAvg: _downAvg,
          peakDown: _peakDown,
          upAvg: _upAvg,
          downSamples: _downSamples,
          onStart: _start,
        );
      case _SpeedPhase.ping:
        return _RunningCard(
          label: 'speedTest.phase.ping'.tr,
          detail: _pingAvg == null
              ? null
              : 'speedTest.avgLatency'.trParams(
                  {'value': _pingAvg!.toStringAsFixed(0)},
                ),
          onCancel: _cancel,
        );
      case _SpeedPhase.download:
        return _DownloadCard(
          samples: _downSamples,
          onCancel: _cancel,
        );
      case _SpeedPhase.upload:
        return _RunningCard(
          label: 'speedTest.phase.upload'.tr,
          onCancel: _cancel,
        );
    }
  }
}

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({
    required this.phase,
    required this.pingMin,
    required this.pingAvg,
    required this.jitter,
    required this.downAvg,
    required this.peakDown,
    required this.upAvg,
    required this.downSamples,
    required this.onStart,
  });

  final _SpeedPhase phase;
  final int? pingMin;
  final double? pingAvg;
  final double? jitter;
  final double? downAvg;
  final double? peakDown;
  final double? upAvg;
  final List<double> downSamples;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final hasResults = phase == _SpeedPhase.done;

    return GlassCard(
      gradientTint: true,
      padding: EdgeInsets.all(tokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hasResults) ...[
            Icon(
              Icons.speed_outlined,
              size: 44,
              color: theme.colorScheme.primary,
            ),
            SizedBox(height: tokens.space2),
            Text(
              'speedTest.intro'.tr,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            SizedBox(height: tokens.space1),
            Text(
              'speedTest.introHint'.tr,
              textAlign: TextAlign.center,
              style: AppText.muted(context),
            ),
          ] else ...[
            Text(
              'speedTest.resultsTitle'.tr,
              style: theme.textTheme.titleMedium,
            ),
            SizedBox(height: tokens.space2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _MetricBlock(
                    label: 'speedTest.download'.tr,
                    value: downAvg,
                    unit: 'Mbps',
                    emphasize: true,
                  ),
                ),
                Expanded(
                  child: _MetricBlock(
                    label: 'speedTest.upload'.tr,
                    value: upAvg,
                    unit: 'Mbps',
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.space2),
            if (downSamples.isNotEmpty)
              SizedBox(
                height: 64,
                child: Sparkline(data: downSamples),
              ),
            SizedBox(height: tokens.space2),
            Row(
              children: [
                Expanded(
                  child: _MetricBlock(
                    label: 'speedTest.latency'.tr,
                    value: pingAvg,
                    unit: 'ms',
                    decimals: 0,
                  ),
                ),
                Expanded(
                  child: _MetricBlock(
                    label: 'speedTest.jitter'.tr,
                    value: jitter,
                    unit: 'ms',
                    decimals: 1,
                  ),
                ),
                Expanded(
                  child: _MetricBlock(
                    label: 'speedTest.best'.tr,
                    value: pingMin?.toDouble(),
                    unit: 'ms',
                    decimals: 0,
                  ),
                ),
              ],
            ),
            if (peakDown != null) ...[
              SizedBox(height: tokens.space1),
              Text(
                'speedTest.peak'.trParams(
                  {'value': peakDown!.toStringAsFixed(1)},
                ),
                style: AppText.muted(context),
              ),
            ],
          ],
          SizedBox(height: tokens.space3),
          FilledButton.icon(
            onPressed: onStart,
            icon: Icon(hasResults ? Icons.replay : Icons.play_arrow),
            label: Text(
              hasResults ? 'speedTest.rerun'.tr : 'speedTest.start'.tr,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    required this.unit,
    this.decimals = 1,
    this.emphasize = false,
  });

  final String label;
  final double? value;
  final String unit;
  final int decimals;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? '—'
        : '${value!.toStringAsFixed(decimals)} $unit';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppText.muted(context)),
        Text(
          text,
          style: emphasize
              ? AppText.heroNumeric(context)
              : AppText.numeric(context),
        ),
      ],
    );
  }
}

class _RunningCard extends StatelessWidget {
  const _RunningCard({
    required this.label,
    this.detail,
    required this.onCancel,
  });

  final String label;
  final String? detail;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return GlassCard(
      padding: EdgeInsets.all(tokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              SizedBox(width: tokens.space2),
              Expanded(child: Text(label, style: AppText.numeric(context))),
            ],
          ),
          if (detail != null) ...[
            SizedBox(height: tokens.space2),
            Text(detail!, style: AppText.heroNumeric(context)),
          ],
          SizedBox(height: tokens.space3),
          OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.stop),
            label: Text('speedTest.cancel'.tr),
          ),
        ],
      ),
    );
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({required this.samples, required this.onCancel});

  final List<double> samples;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final latest = samples.isEmpty ? null : samples.last;
    return GlassCard(
      gradientTint: true,
      padding: EdgeInsets.all(tokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('speedTest.phase.download'.tr, style: AppText.muted(context)),
          Text(
            latest == null ? '…' : '${latest.toStringAsFixed(1)} Mbps',
            style: AppText.heroNumeric(context),
          ),
          SizedBox(height: tokens.space2),
          SizedBox(
            height: 96,
            child: Sparkline(data: samples),
          ),
          SizedBox(height: tokens.space3),
          OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.stop),
            label: Text('speedTest.cancel'.tr),
          ),
        ],
      ),
    );
  }
}

extension on List<int> {
  double get average => isEmpty ? 0 : reduce((a, b) => a + b) / length;
}
