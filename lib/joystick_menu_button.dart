import 'dart:math' as math;
import 'package:flutter/material.dart';

// =============================================================================
// MODEL
// =============================================================================

/// A single selectable option in a [StickButtonMenu].
///
/// [T] is the type of the value associated with the option. When the stick
/// enters this option's radial sector, the menu fires its `onSelected`
/// callback with this [value].
class OptionItem<T> {
  const OptionItem({
    required this.value,
    this.child,
    this.showProgressRing = false,
  });

  /// The value emitted via `onSelected` when this option is activated.
  final T value;

  /// Optional custom widget (icon, label, etc.) for this option.
  ///
  /// When null, a default visual style is applied by the menu
  /// (see [StickButtonMenu.optionBuilder] / default rendering).
  final Widget? child;

  /// Whether to show the activation progress ring when this option is hovered.
  ///
  /// Defaults to `true`. Set to `false` to disable the ring for this option.
  final bool showProgressRing;
}

// =============================================================================
// BUILDER TYPEDEFS
// =============================================================================

/// Builds the circular background of the menu.
typedef MenuBackgroundBuilder =
    Widget Function(BuildContext context, double radius);

/// Builds the central draggable "stick" button.
typedef MenuButtonBuilder =
    Widget Function(
      BuildContext context,
      double size,
      Color color,
      bool isActive,
      double activation,
      int hoverIndex,
    );

/// Builds a single radial option.
///
/// [isHovered] is true when the stick is currently inside this option's sector.
/// [activation] is meaningful only when [isHovered] is true — it ranges from
/// 0.0 (at the dead-zone edge) to 1.0 (at the field edge).
typedef MenuOptionBuilder<T> =
    Widget Function(
      BuildContext context,
      OptionItem<T> option,
      int index,
      bool isHovered,
      double activation,
    );

/// Fired continuously while the stick is engaged with an option.
///
/// [value]      – the activated option's value, or `null` in the neutral zone.
/// [dragDistance] – the stick's offset from center (clamped to the field).
/// [activation] – how far the stick has traveled within the option's range,
///                from `0.0` at the dead-zone edge to `1.0` at the field edge.
///                `0.0` whenever [value] is `null`.
typedef OptionSelectedCallback<T> =
    void Function(T? value, Offset dragDistance, double activation);

// =============================================================================
// CONTROLLER
// =============================================================================

/// Optional controller to programmatically force the menu visible.
///
/// Useful, e.g., to keep the menu shown while video playback is paused.
class StickButtonMenuController extends ChangeNotifier {
  bool _forceVisible = false;

  /// Whether the menu is being forced visible programmatically.
  bool get forceVisible => _forceVisible;

  /// Force the menu to appear (centered in the host area) and stay visible.
  void show() {
    if (_forceVisible) return;
    _forceVisible = true;
    notifyListeners();
  }

  /// Stop forcing visibility. The menu hides unless a gesture is in progress.
  void hide() {
    if (!_forceVisible) return;
    _forceVisible = false;
    notifyListeners();
  }

  /// Toggle forced visibility.
  void toggle() => _forceVisible ? hide() : show();
}

// =============================================================================
// WIDGET
// =============================================================================

/// A floating, joystick-style radial menu for touch-driven controls.
///
/// The menu is **hidden by default**. A long-press on the [child] reveals it,
/// centered at the touch point. Without lifting the finger, the user drags the
/// central "stick" toward one of the radial [options] to activate it. Lifting
/// the finger hides the menu and animates the stick back to center.
///
/// The menu renders as an overlay on top of [child] using a [Stack], so it
/// does not affect the child's layout.
class StickButtonMenu<T> extends StatefulWidget {
  const StickButtonMenu({
    super.key,
    required this.options,
    required this.child,
    this.onSelected,
    this.controller,
    // Geometry
    this.radius = 110.0,
    this.buttonRatio,
    this.placeholderRatio = 0.42,
    this.optionRatio,
    // Colors
    this.backgroundColor = const Color(0xCC4A4A4A),
    this.buttonColor = const Color(0xFFE0B83C),
    this.buttonActiveColor = const Color(0xFFF2C94C),
    this.dividerColor = const Color(0x33FFFFFF),
    this.optionColor = const Color(0x22FFFFFF),
    this.optionHoverColor = const Color(0x55FFFFFF),
    this.iconColor = Colors.white70,
    // Behavior
    this.dividerWidth = 1.0,
    this.showDividers = true,
    this.appearDuration = const Duration(milliseconds: 160),
    this.returnDuration = const Duration(milliseconds: 220),
    // Custom builders
    this.backgroundBuilder,
    this.buttonBuilder,
    this.optionBuilder,
  }) : assert(options.length > 0, 'Provide at least one option.'),
       assert(buttonRatio == null || (buttonRatio > 0 && buttonRatio < 1)),
       assert(placeholderRatio > 0 && placeholderRatio < 1),
       assert(optionRatio == null || (optionRatio > 0 && optionRatio < 1));

  /// The content the menu floats above.
  final Widget child;

  /// The radial options. The circle is divided into equal sectors by count.
  final List<OptionItem<T>> options;

  /// Fired when an option is hovered/activated, or when returning to neutral.
  final OptionSelectedCallback<T>? onSelected;

  /// Optional controller to programmatically force visibility.
  final StickButtonMenuController? controller;

  // --- Geometry ---

  /// Overall radius of the menu (half its diameter).
  final double radius;

  /// Diameter of the central button as a fraction of the menu diameter.
  ///
  /// When `null` (the default), the ratio is auto-computed based on the number
  /// of options so that markers don't overlap.
  final double? buttonRatio;

  /// Radius of the center neutral "dead-zone" as a fraction of menu radius.
  final double placeholderRatio;

  /// Diameter of each option marker as a fraction of the menu diameter.
  ///
  /// When `null` (the default), the ratio is auto-computed based on the number
  /// of options so that markers don't overlap.
  final double? optionRatio;

  // --- Colors ---
  final Color backgroundColor;
  final Color buttonColor;
  final Color buttonActiveColor;
  final Color dividerColor;
  final Color optionColor;
  final Color optionHoverColor;
  final Color iconColor;

  // --- Behavior / Style ---
  final double dividerWidth;
  final bool showDividers;
  final Duration appearDuration;
  final Duration returnDuration;

  // --- Custom builders (full visual control) ---
  final MenuBackgroundBuilder? backgroundBuilder;
  final MenuButtonBuilder? buttonBuilder;
  final MenuOptionBuilder<T>? optionBuilder;

  @override
  State<StickButtonMenu<T>> createState() => _StickButtonMenuState<T>();
}

class _StickButtonMenuState<T> extends State<StickButtonMenu<T>>
    with SingleTickerProviderStateMixin {
  /// Whether the menu is currently visible (via gesture or controller).
  bool _visible = false;

  /// Whether a drag gesture is currently in progress (finger still down).
  bool _dragging = false;

  /// Center of the menu in the local coordinate space of this widget.
  Offset _menuCenter = Offset.zero;

  /// Current stick offset relative to [_menuCenter], clamped to drag radius.
  Offset _stickOffset = Offset.zero;

  /// Index of the currently-hovered option, or -1 for the neutral center.
  int _hoveredIndex = -1;

  /// Current activation intensity [0..1] of the hovered option.
  double _activation = 0.0;

  /// Min change in activation before we re-emit (throttles callback noise).
  static const double _activationEpsilon = 0.005;

  /// Animation that returns the stick smoothly to center on release.
  late final AnimationController _returnController;
  Animation<Offset>? _returnAnim;

  @override
  void initState() {
    super.initState();
    _returnController = AnimationController(
      vsync: this,
      duration: widget.returnDuration,
    )..addListener(_onReturnTick);

    widget.controller?.addListener(_onControllerChanged);
    // Reflect any initial forced-visible state.
    if (widget.controller?.forceVisible ?? false) {
      _visible = true;
    }
  }

  @override
  void didUpdateWidget(covariant StickButtonMenu<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      widget.controller?.addListener(_onControllerChanged);
    }
    _returnController.duration = widget.returnDuration;
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    _returnController
      ..removeListener(_onReturnTick)
      ..dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Derived geometry helpers
  // ---------------------------------------------------------------------------

  double get _diameter => widget.radius * 2;

  /// Auto-compute a ratio that shrinks as option count grows.
  ///
  /// Base of 0.34 for ≤ 3 options, linearly shrinking to a floor of 0.14
  /// at 10+ options.
  static double _autoRatio(int optionCount) {
    const base = 0.44;
    const floor = 0.14;
    const rampStart = 3;
    const rampEnd = 10;
    if (optionCount <= rampStart) return base;
    if (optionCount >= rampEnd) return floor;
    return base -
        (base - floor) * (optionCount - rampStart) / (rampEnd - rampStart);
  }

  double get _resolvedButtonRatio =>
      widget.buttonRatio ?? _autoRatio(widget.options.length);
  double get _resolvedOptionRatio =>
      widget.optionRatio ?? _autoRatio(widget.options.length);

  double get _buttonSize => _diameter * _resolvedButtonRatio;

  /// Max distance the stick can travel from center.
  double get _dragRadius => widget.radius - _buttonSize / 2;

  /// Radius of the neutral dead-zone in the center.
  double get _deadZoneRadius => widget.radius * widget.placeholderRatio;

  // ---------------------------------------------------------------------------
  // Controller
  // ---------------------------------------------------------------------------

  void _onControllerChanged() {
    final force = widget.controller?.forceVisible ?? false;
    if (force && !_visible) {
      // Show centered in the host area; center is resolved at layout via build.
      setState(() {
        _visible = true;
        // If we have no live touch center yet, center within the widget bounds.
        if (!_dragging) {
          _stickOffset = Offset.zero;
          _hoveredIndex = -1;
        }
      });
    } else if (!force && !_dragging) {
      _hide();
    }
  }

  // ---------------------------------------------------------------------------
  // Gesture handling
  // ---------------------------------------------------------------------------

  void _handleLongPressStart(LongPressStartDetails details) {
    _returnController.stop();
    setState(() {
      _visible = true;
      _dragging = true;
      _menuCenter = details.localPosition;
      _stickOffset = Offset.zero;
      _hoveredIndex = -1;
    });
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_dragging) return;
    _updateStick(details.localPosition - _menuCenter);
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    _dragging = false;
    final force = widget.controller?.forceVisible ?? false;
    if (force) {
      // Stay visible (e.g. paused playback); just animate stick to center.
      _animateStickToCenter(keepVisible: true);
    } else {
      _animateStickToCenter(keepVisible: false);
    }
  }

  /// Normalized activation [0..1] of the stick within the active option's range.
  ///
  /// 0.0 at the dead-zone boundary (just engaged), 1.0 at the field edge.
  double _activationFor(Offset offset) {
    final span = _dragRadius - _deadZoneRadius;
    if (span <= 0) return 0.0;
    final t = (offset.distance - _deadZoneRadius) / span;
    return t.clamp(0.0, 1.0);
  }

  /// Update the stick to a new raw offset, clamping to the drag radius and
  /// recomputing the hovered option sector.
  void _updateStick(Offset rawOffset) {
    final distance = rawOffset.distance;
    final clamped = distance > _dragRadius
        ? Offset.fromDirection(rawOffset.direction, _dragRadius)
        : rawOffset;

    final newIndex = _sectorForOffset(clamped);
    final activation = newIndex >= 0 ? _activationFor(clamped) : 0.0;

    // Only rebuild / emit if something meaningful changed (avoids spam).
    final indexChanged = newIndex != _hoveredIndex;
    final activationChanged =
        (activation - _activation).abs() >= _activationEpsilon;

    if (!indexChanged && !activationChanged) {
      // Still update stick position for smooth visuals without re-emitting.
      if (clamped != _stickOffset) {
        setState(() => _stickOffset = clamped);
      }
      return;
    }

    setState(() {
      _stickOffset = clamped;
      _hoveredIndex = newIndex;
      _activation = activation;
    });

    final value = newIndex >= 0 ? widget.options[newIndex].value : null;
    widget.onSelected?.call(value, clamped, activation);
  }

  /// Returns the option index for a stick [offset], or -1 for the dead-zone.
  int _sectorForOffset(Offset offset) {
    if (offset.distance < _deadZoneRadius) return -1;

    final count = widget.options.length;
    // Angle measured clockwise from straight up (12 o'clock).
    // atan2(dx, -dy) gives 0 at top, increasing clockwise.
    double angle = math.atan2(offset.dx, -offset.dy);
    if (angle < 0) angle += 2 * math.pi;

    final sectorSize = 2 * math.pi / count;
    // Shift by half a sector so option 0 is centered at the top.
    final shifted = (angle + sectorSize / 2) % (2 * math.pi);
    return (shifted ~/ sectorSize) % count;
  }

  // ---------------------------------------------------------------------------
  // Return-to-center animation
  // ---------------------------------------------------------------------------

  bool _hideAfterReturn = true;

  void _animateStickToCenter({required bool keepVisible}) {
    _hideAfterReturn = !keepVisible;
    _returnAnim = Tween<Offset>(begin: _stickOffset, end: Offset.zero).animate(
      CurvedAnimation(parent: _returnController, curve: Curves.easeOutBack),
    );
    _returnController
      ..reset()
      ..forward().whenComplete(_onReturnComplete);

    // Emit neutral selection if we were on an option.
    if (_hoveredIndex != -1) {
      _hoveredIndex = -1;
      _activation = 0.0;
      widget.onSelected?.call(null, Offset.zero, 0.0);
    }
  }

  void _onReturnTick() {
    final anim = _returnAnim;
    if (anim == null) return;
    setState(() => _stickOffset = anim.value);
  }

  void _onReturnComplete() {
    if (_hideAfterReturn && !(widget.controller?.forceVisible ?? false)) {
      _hide();
    }
  }

  void _hide() {
    if (!mounted) return;
    setState(() {
      _visible = false;
      _dragging = false;
      _stickOffset = Offset.zero;
      _hoveredIndex = -1;
      _activation = 0.0;
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // When forced visible without a live touch, center in the host area.
        final forced = widget.controller?.forceVisible ?? false;
        final center = (!_dragging && forced && _menuCenter == Offset.zero)
            ? Offset(constraints.maxWidth / 2, constraints.maxHeight / 2)
            : _menuCenter;

        return Stack(
          children: [
            // The child content. The menu floats above it as an overlay.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPressStart: _handleLongPressStart,
                onLongPressMoveUpdate: _handleLongPressMoveUpdate,
                onLongPressEnd: _handleLongPressEnd,
                child: widget.child,
              ),
            ),

            // The floating radial menu overlay.
            if (_visible)
              Positioned(
                left: center.dx - widget.radius,
                top: center.dy - widget.radius,
                width: _diameter,
                height: _diameter,
                child: IgnorePointer(
                  // The menu is driven by the underlying long-press recognizer,
                  // so it should not intercept pointer events itself.
                  child: _buildMenu(context),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMenu(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: widget.appearDuration,
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return Opacity(
          opacity: t,
          child: Transform.scale(
            scale: 0.85 + 0.15 * t,
            child: SizedBox(
              width: _diameter,
              height: _diameter,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 1. Background circle.
                  _buildBackground(context),

                  // 2. Sector dividers.
                  if (widget.showDividers && widget.options.length > 1)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _DividerPainter(
                          count: widget.options.length,
                          color: widget.dividerColor,
                          strokeWidth: widget.dividerWidth,
                          deadZoneRadius: _deadZoneRadius,
                        ),
                      ),
                    ),

                  // 3. Radial option markers.
                  ..._buildOptions(context),

                  // 4. Central draggable stick button.
                  Transform.translate(
                    offset: _stickOffset,
                    child: _buildButton(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackground(BuildContext context) {
    if (widget.backgroundBuilder != null) {
      return widget.backgroundBuilder!(context, widget.radius);
    }
    return Container(
      width: _diameter,
      height: _diameter,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildButton(BuildContext context) {
    final isActive = _hoveredIndex != -1;
    final color = isActive
        ? Color.lerp(widget.buttonColor, widget.buttonActiveColor, _activation)!
        : widget.buttonColor;
    if (widget.buttonBuilder != null) {
      return widget.buttonBuilder!(
        context,
        _buttonSize,
        color,
        isActive,
        _activation,
        _hoveredIndex,
      );
    }

    return Container(
      width: _buttonSize,
      height: _buttonSize,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOptions(BuildContext context) {
    final count = widget.options.length;
    final optionSize = _diameter * _resolvedOptionRatio;
    // Distance from center at which option markers sit.
    final orbit = widget.radius - optionSize / 2 - 4;
    final sectorSize = 2 * math.pi / count;

    return List.generate(count, (i) {
      // Angle measured clockwise from top; option 0 centered at top.
      final angle = i * sectorSize;
      // Convert "clockwise-from-top" to standard math coordinates.
      final dx = orbit * math.sin(angle);
      final dy = -orbit * math.cos(angle);

      final option = widget.options[i];
      final isHovered = _hoveredIndex == i;
      final activation = isHovered ? _activation : 0.0;

      final Widget content;
      if (widget.optionBuilder != null) {
        content = widget.optionBuilder!(
          context,
          option,
          i,
          isHovered,
          activation,
        );
      } else {
        content = _defaultOption(option, optionSize, isHovered, activation);
      }

      return Transform.translate(offset: Offset(dx, dy), child: content);
    });
  }

  Widget _defaultOption(
    OptionItem<T> option,
    double size,
    bool isHovered,
    double activation,
  ) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base marker.
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isHovered ? widget.optionHoverColor : widget.optionColor,
              shape: BoxShape.circle,
            ),
          ),
          // Activation progress ring (grows 0 → 100%).
          if (isHovered && option.showProgressRing)
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: activation,
                strokeWidth: 3,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(widget.iconColor),
              ),
            ),
          // Icon / label.
          IconTheme.merge(
            data: IconThemeData(color: widget.iconColor, size: size * 0.5),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: widget.iconColor, fontSize: size * 0.3),
              child: option.child ?? const Icon(Icons.circle_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PAINTER
// =============================================================================

/// Paints equally-spaced radial dividers between option sectors.
///
/// Divider lines are drawn on the *boundaries* between sectors (offset by half
/// a sector from the option centers), starting outside the dead-zone.
class _DividerPainter extends CustomPainter {
  _DividerPainter({
    required this.count,
    required this.color,
    required this.strokeWidth,
    required this.deadZoneRadius,
  });

  final int count;
  final Color color;
  final double strokeWidth;
  final double deadZoneRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final sectorSize = 2 * math.pi / count;
    for (int i = 0; i < count; i++) {
      // Boundary lines sit halfway between option centers.
      final angle = i * sectorSize + sectorSize / 2;
      // Clockwise-from-top → math coords.
      final dir = Offset(math.sin(angle), -math.cos(angle));
      final start = center + dir * deadZoneRadius;
      final end = center + dir * radius;
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DividerPainter old) {
    return old.count != count ||
        old.color != color ||
        old.strokeWidth != strokeWidth ||
        old.deadZoneRadius != deadZoneRadius;
  }
}
