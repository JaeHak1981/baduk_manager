import 'package:flutter/material.dart';
import '../../providers/attendance_provider.dart';

class RemarkCell extends StatefulWidget {
  final AttendanceProvider provider;
  final String studentId;
  final String academyId;
  final String ownerId;
  final DateTime date;
  final String initialNote;

  const RemarkCell({
    super.key,
    required this.provider,
    required this.studentId,
    required this.academyId,
    required this.ownerId,
    required this.date,
    required this.initialNote,
  });

  @override
  State<RemarkCell> createState() => _RemarkCellState();
}

class _RemarkCellState extends State<RemarkCell> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late String _lastSavedNote;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote);
    _lastSavedNote = widget.initialNote;
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(RemarkCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialNote != oldWidget.initialNote && !_focusNode.hasFocus) {
      _controller.text = widget.initialNote;
      _lastSavedNote = widget.initialNote;
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _saveNote();
    }
  }

  void _saveNote() {
    final text = _controller.text.trim();
    if (text != _lastSavedNote) {
      widget.provider.updateNote(
        studentId: widget.studentId,
        academyId: widget.academyId,
        ownerId: widget.ownerId,
        date: widget.date,
        note: text,
      );
      _lastSavedNote = text;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: const TextStyle(fontSize: 12),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          border: InputBorder.none,
          hintText: '비고 입력...',
          hintStyle: TextStyle(fontSize: 10, color: Colors.grey),
        ),
        onSubmitted: (_) => _saveNote(),
      ),
    );
  }
}
