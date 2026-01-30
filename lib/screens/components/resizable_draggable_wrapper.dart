import 'package:flutter/material.dart';

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

  final double _handleSize = 12.0;
  final double _edgeSize = 8.0;

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

  void _notifyChange() {
    widget.onLayoutChanged(top, left, width, height);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEditing) {
      return Positioned(
        top: top,
        left: left,
        width: width,
        height: height,
        child: widget.child,
      );
    }

    return Positioned(
      top: top,
      left: left,
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The actual content
          SizedBox(
            width: width,
            height: height,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.indigo.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: widget.child,
            ),
          ),

          // Drag handle (Overlay)
          Positioned.fill(
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  top += details.delta.dy;
                  left += details.delta.dx;
                });
              },
              onPanEnd: (_) => _notifyChange(),
            ),
          ),

          // REASIZE HANDLES

          // Top
          Positioned(
            top: -_edgeSize / 2,
            left: _handleSize,
            right: _handleSize,
            height: _edgeSize,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeUpDown,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    if (height != null) {
                      double delta = details.delta.dy;
                      top += delta;
                      height = (height! - delta).clamp(20.0, double.infinity);
                    }
                  });
                },
                onPanEnd: (_) => _notifyChange(),
              ),
            ),
          ),

          // Bottom
          Positioned(
            bottom: -_edgeSize / 2,
            left: _handleSize,
            right: _handleSize,
            height: _edgeSize,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeUpDown,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    if (height != null) {
                      height = (height! + details.delta.dy).clamp(
                        20.0,
                        double.infinity,
                      );
                    }
                  });
                },
                onPanEnd: (_) => _notifyChange(),
              ),
            ),
          ),

          // Left
          Positioned(
            left: -_edgeSize / 2,
            top: _handleSize,
            bottom: _handleSize,
            width: _edgeSize,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    if (width != null) {
                      double delta = details.delta.dx;
                      left += delta;
                      width = (width! - delta).clamp(20.0, double.infinity);
                    }
                  });
                },
                onPanEnd: (_) => _notifyChange(),
              ),
            ),
          ),

          // Right
          Positioned(
            right: -_edgeSize / 2,
            top: _handleSize,
            bottom: _handleSize,
            width: _edgeSize,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    if (width != null) {
                      width = (width! + details.delta.dx).clamp(
                        20.0,
                        double.infinity,
                      );
                    }
                  });
                },
                onPanEnd: (_) => _notifyChange(),
              ),
            ),
          ),

          // Corners
          _buildCornerHandle(
            top: -_handleSize / 2,
            left: -_handleSize / 2,
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
            top: -_handleSize / 2,
            right: -_handleSize / 2,
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
            bottom: -_handleSize / 2,
            left: -_handleSize / 2,
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
            bottom: -_handleSize / 2,
            right: -_handleSize / 2,
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
      width: _handleSize,
      height: _handleSize,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          onPanUpdate: onUpdate,
          onPanEnd: (_) => _notifyChange(),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.indigo, width: 2),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
