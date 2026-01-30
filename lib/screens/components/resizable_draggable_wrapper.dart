import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ResizableDraggableWrapper extends StatefulWidget {
  final Widget child;
  final double initialTop;
  final double initialLeft;
  final double? initialWidth;
  final double? initialHeight;
  final bool isEditing;
  final Function(double top, double left, double? width, double? height)
  onLayoutChanged;

  const ResizableDraggableWrapper({
    super.key,
    required this.child,
    required this.initialTop,
    required this.initialLeft,
    this.initialWidth,
    this.initialHeight,
    required this.isEditing,
    required this.onLayoutChanged,
  });

  @override
  State<ResizableDraggableWrapper> createState() =>
      _ResizableDraggableWrapperState();
}

class _ResizableDraggableWrapperState extends State<ResizableDraggableWrapper> {
  late double top;
  late double left;
  double? width;
  double? height;

  // 히트박스 영역 확대 및 내부 배치(Inner Handles) 적용
  final double _handleSize = 10.0; // 눈에 보이는 점 크기
  final double _hitAreaSize = 40.0; // 실제 클릭 인식 영역 (확대)
  final double _edgeHitSize = 30.0; // 변(Edge) 클릭 인식 영역 (확대)
  final double _gridSize = 10.0; // 그리드 스냅 단위

  bool _isFocused = false;
  bool _isDragging = false;
  bool _isResizing = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    top = widget.initialTop;
    left = widget.initialLeft;
    width = widget.initialWidth;
    height = widget.initialHeight;
  }

  @override
  void didUpdateWidget(ResizableDraggableWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTop != widget.initialTop ||
        oldWidget.initialLeft != widget.initialLeft ||
        oldWidget.initialWidth != widget.initialWidth ||
        oldWidget.initialHeight != widget.initialHeight) {
      setState(() {
        top = widget.initialTop;
        left = widget.initialLeft;
        width = widget.initialWidth;
        height = widget.initialHeight;
      });
    }
  }

  // 그리드 스냅 적용 함수
  double _snap(double value) {
    return (value / _gridSize).roundToDouble() * _gridSize;
  }

  void _notifyChange() {
    widget.onLayoutChanged(top, left, width, height);
  }

  // 키보드 미세 조절 핸들러
  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    setState(() {
      final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
      final step = isShiftPressed ? 10.0 : 1.0;

      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        top -= step;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        top += step;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        left -= step;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        left += step;
      } else if (event.logicalKey == LogicalKeyboardKey.bracketRight) {
        if (width != null) width = width! + step;
      } else if (event.logicalKey == LogicalKeyboardKey.bracketLeft) {
        if (width != null) width = (width! - step).clamp(20.0, double.infinity);
      } else if (event.logicalKey == LogicalKeyboardKey.equal) {
        if (height != null) height = height! + step;
      } else if (event.logicalKey == LogicalKeyboardKey.minus) {
        if (height != null)
          height = (height! - step).clamp(20.0, double.infinity);
      }
    });
    _notifyChange();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEditing) {
      return Positioned(
        top: top,
        left: left,
        width: width,
        height: height,
        child: ClipRect(child: widget.child),
      );
    }

    return Positioned(
      top: top,
      left: left,
      width: width,
      height: height,
      child: Focus(
        focusNode: _focusNode,
        onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
        onKeyEvent: (node, event) {
          _handleKeyEvent(event);
          return KeyEventResult.handled;
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 실제 콘텐츠 영역
            SizedBox(
              width: width,
              height: height,
              child: Container(
                decoration: BoxDecoration(
                  color: _isFocused ? Colors.indigo.withOpacity(0.02) : null,
                  boxShadow: _isDragging
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : null,
                  border: Border.all(
                    color: _isDragging
                        ? Colors.orange
                        : (_isResizing
                              ? Colors.teal
                              : (_isFocused
                                    ? Colors.indigo
                                    : Colors.indigo.withOpacity(0.3))),
                    width: (_isFocused || _isDragging || _isResizing) ? 2 : 1,
                  ),
                ),
                child: ClipRect(child: widget.child),
              ),
            ),

            // 이동용 핸들 아이콘 (상단 중앙)
            Positioned(
              top: -25,
              left: 0,
              right: 0,
              child: Center(
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.indigo,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.open_with,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),

            // 전체 드래그 핸들 (오버레이)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _focusNode.requestFocus(),
                onPanStart: (_) {
                  _focusNode.requestFocus();
                  setState(() => _isDragging = true);
                },
                onPanUpdate: (details) {
                  setState(() {
                    top += details.delta.dy;
                    left += details.delta.dx;
                  });
                },
                onPanEnd: (_) {
                  setState(() {
                    _isDragging = false;
                    top = _snap(top);
                    left = _snap(left);
                  });
                  _notifyChange();
                },
              ),
            ),

            // 크기 조절 핸들 (상/하/좌/우 변)

            // Top Edge
            _buildEdgeHandle(
              top: -10.0, // 상단 10px만 밖으로, 20px은 안으로 (벽 접착 대비)
              left: _handleSize,
              right: _handleSize,
              height: _edgeHitSize,
              cursor: SystemMouseCursors.resizeUpDown,
              onUpdate: (details) {
                setState(() {
                  if (height != null) {
                    double delta = details.delta.dy;
                    top += delta;
                    height = (height! - delta).clamp(20.0, double.infinity);
                  }
                });
              },
            ),

            // Bottom Edge
            _buildEdgeHandle(
              bottom: -10.0,
              left: _handleSize,
              right: _handleSize,
              height: _edgeHitSize,
              cursor: SystemMouseCursors.resizeUpDown,
              onUpdate: (details) {
                setState(() {
                  if (height != null) {
                    height = (height! + details.delta.dy).clamp(
                      20.0,
                      double.infinity,
                    );
                  }
                });
              },
            ),

            // Left Edge
            _buildEdgeHandle(
              left: -10.0,
              top: _handleSize,
              bottom: _handleSize,
              width: _edgeHitSize,
              cursor: SystemMouseCursors.resizeLeftRight,
              onUpdate: (details) {
                setState(() {
                  if (width != null) {
                    double delta = details.delta.dx;
                    left += delta;
                    width = (width! - delta).clamp(20.0, double.infinity);
                  }
                });
              },
            ),

            // Right Edge
            _buildEdgeHandle(
              right: -10.0,
              top: _handleSize,
              bottom: _handleSize,
              width: _edgeHitSize,
              cursor: SystemMouseCursors.resizeLeftRight,
              onUpdate: (details) {
                setState(() {
                  if (width != null) {
                    width = (width! + details.delta.dx).clamp(
                      20.0,
                      double.infinity,
                    );
                  }
                });
              },
            ),

            // 모서리 핸들 (Corners - 안쪽으로 이동하여 벽에서도 잡힐 수 있게 함)
            _buildCornerHandle(
              top: -10.0,
              left: -10.0,
              cursor: SystemMouseCursors.resizeUpLeftDownRight,
              onUpdate: (details) {
                setState(() {
                  double dx = details.delta.dx;
                  double dy = details.delta.dy;
                  top += dy;
                  left += dx;
                  if (width != null)
                    width = (width! - dx).clamp(20.0, double.infinity);
                  if (height != null)
                    height = (height! - dy).clamp(20.0, double.infinity);
                });
              },
            ),
            _buildCornerHandle(
              top: -10.0,
              right: -10.0,
              cursor: SystemMouseCursors.resizeUpRightDownLeft,
              onUpdate: (details) {
                setState(() {
                  double dy = details.delta.dy;
                  top += dy;
                  if (width != null)
                    width = (width! + details.delta.dx).clamp(
                      20.0,
                      double.infinity,
                    );
                  if (height != null)
                    height = (height! - dy).clamp(20.0, double.infinity);
                });
              },
            ),
            _buildCornerHandle(
              bottom: -10.0,
              left: -10.0,
              cursor: SystemMouseCursors.resizeUpRightDownLeft,
              onUpdate: (details) {
                setState(() {
                  double dx = details.delta.dx;
                  left += dx;
                  if (width != null)
                    width = (width! - dx).clamp(20.0, double.infinity);
                  if (height != null)
                    height = (height! + details.delta.dy).clamp(
                      20.0,
                      double.infinity,
                    );
                });
              },
            ),
            _buildCornerHandle(
              bottom: -10.0,
              right: -10.0,
              cursor: SystemMouseCursors.resizeUpLeftDownRight,
              onUpdate: (details) {
                setState(() {
                  if (width != null)
                    width = (width! + details.delta.dx).clamp(
                      20.0,
                      double.infinity,
                    );
                  if (height != null)
                    height = (height! + details.delta.dy).clamp(
                      20.0,
                      double.infinity,
                    );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEdgeHandle({
    double? top,
    double? bottom,
    double? left,
    double? right,
    double? width,
    double? height,
    required MouseCursor cursor,
    required Function(DragUpdateDetails) onUpdate,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      width: width,
      height: height,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => setState(() => _isResizing = true),
          onPanUpdate: onUpdate,
          onPanEnd: (_) {
            setState(() {
              _isResizing = false;
              this.top = _snap(this.top);
              this.left = _snap(this.left);
              if (this.width != null) this.width = _snap(this.width!);
              if (this.height != null) this.height = _snap(this.height!);
            });
            _notifyChange();
          },
        ),
      ),
    );
  }

  Widget _buildCornerHandle({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required MouseCursor cursor,
    required Function(DragUpdateDetails) onUpdate,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      width: _hitAreaSize,
      height: _hitAreaSize,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => setState(() => _isResizing = true),
          onPanUpdate: onUpdate,
          onPanEnd: (_) {
            setState(() {
              _isResizing = false;
              this.top = _snap(this.top);
              this.left = _snap(this.left);
              if (this.width != null) this.width = _snap(this.width!);
              if (this.height != null) this.height = _snap(this.height!);
            });
            _notifyChange();
          },
          child: Center(
            child: Container(
              width: _handleSize,
              height: _handleSize,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.indigo, width: 2),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
