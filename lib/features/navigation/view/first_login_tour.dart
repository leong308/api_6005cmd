import 'dart:async';
import 'dart:math' as math;

import 'package:app_tour_flutter/app_tour_flutter.dart';
import 'package:flutter/material.dart';

class AppTourStep {
  const AppTourStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.beforeShow,
  });

  final GlobalKey targetKey;
  final String title;
  final String description;
  final FutureOr<void> Function()? beforeShow;
}

class AppTourOverlayController {
  OverlayEntry? _overlayEntry;
  BuildContext? _context;
  List<AppTourStep> _steps = const [];
  VoidCallback? _onComplete;
  VoidCallback? _onSkip;
  int _currentIndex = 0;
  bool _active = false;

  bool get isActive => _active;

  Future<void> start({
    required BuildContext context,
    required List<AppTourStep> steps,
    VoidCallback? onComplete,
    VoidCallback? onSkip,
  }) async {
    cancel();
    if (steps.isEmpty) {
      onComplete?.call();
      return;
    }
    _context = context;
    _steps = steps;
    _onComplete = onComplete;
    _onSkip = onSkip;
    _currentIndex = 0;
    _active = true;
    await _showCurrentStep();
  }

  void cancel() {
    _removeOverlay();
    _active = false;
    _context = null;
    _steps = const [];
    _onComplete = null;
    _onSkip = null;
    _currentIndex = 0;
  }

  void dispose() {
    cancel();
  }

  Future<void> _showCurrentStep() async {
    if (!_active) {
      return;
    }
    if (_currentIndex >= _steps.length) {
      final onComplete = _onComplete;
      cancel();
      onComplete?.call();
      return;
    }

    final rootContext = _context;
    if (rootContext == null || !rootContext.mounted) {
      cancel();
      return;
    }

    final step = _steps[_currentIndex];
    await step.beforeShow?.call();
    await WidgetsBinding.instance.endOfFrame;
    if (!_active || !rootContext.mounted) {
      return;
    }

    final targetContext = step.targetKey.currentContext;
    if (targetContext == null || !targetContext.mounted) {
      _currentIndex++;
      await _showCurrentStep();
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
      alignment: 0.5,
    );
    await WidgetsBinding.instance.endOfFrame;
    if (!_active || !rootContext.mounted || !targetContext.mounted) {
      return;
    }

    final renderObject = targetContext.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      _currentIndex++;
      await _showCurrentStep();
      return;
    }

    final screenSize = MediaQuery.sizeOf(rootContext);
    final safePadding = MediaQuery.paddingOf(rootContext);
    final position = renderObject.localToGlobal(Offset.zero);
    final targetSize = renderObject.size;
    const highlightPadding = 12.0;
    final holeRect = Rect.fromLTRB(
      math.max(0, position.dx - highlightPadding),
      math.max(0, position.dy - highlightPadding),
      math.min(
        screenSize.width,
        position.dx + targetSize.width + highlightPadding,
      ),
      math.min(
        screenSize.height,
        position.dy + targetSize.height + highlightPadding,
      ),
    );

    final bubbleMetrics = _bubbleMetrics(
      holeRect: holeRect,
      screenSize: screenSize,
      safePadding: safePadding,
    );
    final overlay = Overlay.maybeOf(rootContext, rootOverlay: true);
    if (overlay == null) {
      cancel();
      return;
    }

    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (_) => _AppTourOverlay(
        holeRect: holeRect,
        bubbleLeft: bubbleMetrics.left,
        bubbleTop: bubbleMetrics.top,
        bubbleWidth: bubbleMetrics.width,
        isBubbleAbove: bubbleMetrics.isAbove,
        trianglePositionPercentage: bubbleMetrics.trianglePositionPercentage,
        title: step.title,
        description: step.description,
        stepNumber: _currentIndex + 1,
        totalSteps: _steps.length,
        onNext: _next,
        onSkip: _skip,
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  _BubbleMetrics _bubbleMetrics({
    required Rect holeRect,
    required Size screenSize,
    required EdgeInsets safePadding,
  }) {
    const estimatedBubbleHeight = 160.0;
    const tooltipGap = 28.0;
    final bubbleWidth = math.min(
      320.0,
      math.max(160.0, screenSize.width - 32.0),
    );
    final targetCenterX = holeRect.left + holeRect.width / 2;
    final maxBubbleLeft = math.max(16.0, screenSize.width - bubbleWidth - 16.0);
    final bubbleLeft = (targetCenterX - bubbleWidth / 2).clamp(
      16.0,
      maxBubbleLeft,
    );
    final safeTop = safePadding.top + 16.0;
    final safeBottom = safePadding.bottom + 16.0;
    final belowTop = holeRect.bottom + tooltipGap;
    final aboveTop = holeRect.top - estimatedBubbleHeight - tooltipGap;
    final hasRoomAbove = aboveTop >= safeTop;
    final hasRoomBelow =
        belowTop + estimatedBubbleHeight <= screenSize.height - safeBottom;
    final useAbove = hasRoomAbove && !hasRoomBelow
        ? true
        : holeRect.center.dy > screenSize.height / 2;
    final rawBubbleTop = useAbove ? aboveTop : belowTop;
    final minTop = safeTop;
    final maxTop = math.max(
      minTop,
      screenSize.height - safeBottom - estimatedBubbleHeight,
    );
    final bubbleTop = rawBubbleTop.clamp(minTop, maxTop);
    final isAbove = bubbleTop < holeRect.top;
    final trianglePositionPercentage =
        ((targetCenterX - bubbleLeft) / bubbleWidth).clamp(0.08, 0.92);

    return _BubbleMetrics(
      left: bubbleLeft.toDouble(),
      top: bubbleTop.toDouble(),
      width: bubbleWidth,
      isAbove: isAbove,
      trianglePositionPercentage: trianglePositionPercentage.toDouble(),
    );
  }

  void _next() {
    if (!_active) {
      return;
    }
    _currentIndex++;
    unawaited(_showCurrentStep());
  }

  void _skip() {
    final onSkip = _onSkip;
    cancel();
    onSkip?.call();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _BubbleMetrics {
  const _BubbleMetrics({
    required this.left,
    required this.top,
    required this.width,
    required this.isAbove,
    required this.trianglePositionPercentage,
  });

  final double left;
  final double top;
  final double width;
  final bool isAbove;
  final double trianglePositionPercentage;
}

class _AppTourOverlay extends StatelessWidget {
  const _AppTourOverlay({
    required this.holeRect,
    required this.bubbleLeft,
    required this.bubbleTop,
    required this.bubbleWidth,
    required this.isBubbleAbove,
    required this.trianglePositionPercentage,
    required this.title,
    required this.description,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
  });

  final Rect holeRect;
  final double bubbleLeft;
  final double bubbleTop;
  final double bubbleWidth;
  final bool isBubbleAbove;
  final double trianglePositionPercentage;
  final String title;
  final String description;
  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final isLastStep = stepNumber == totalSteps;
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: HoleOverlay(holeRect: holeRect, borderRadius: 14),
          ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onNext,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            top: bubbleTop,
            left: bubbleLeft,
            child: GestureDetector(
              onTap: onNext,
              child: CustomSpeechBubble(
                width: bubbleWidth,
                title: title,
                description: description,
                isAbove: isBubbleAbove,
                trianglePositionPercentage: trianglePositionPercentage,
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 16,
            child: Center(
              child: Material(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(999),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text(
                        'Step $stepNumber of $totalSteps',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black87,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton(
                        onPressed: onSkip,
                        child: const Text('Skip tour'),
                      ),
                      FilledButton(
                        onPressed: onNext,
                        child: Text(isLastStep ? 'Done' : 'Next'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
