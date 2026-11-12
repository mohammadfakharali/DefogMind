import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class MathChallengeDialog extends StatefulWidget {
  final String title;
  final String actionDescription;
  final VoidCallback onSolved;

  const MathChallengeDialog({
    super.key,
    this.title = 'Quick Focus Check',
    required this.actionDescription,
    required this.onSolved,
  });

  static void show({
    required BuildContext context,
    required String actionDescription,
    required VoidCallback onSolved,
    String title = 'Quick Focus Check',
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MathChallengeDialog(
        title: title,
        actionDescription: actionDescription,
        onSolved: onSolved,
      ),
    );
  }

  @override
  State<MathChallengeDialog> createState() => _MathChallengeDialogState();
}

class _MathChallengeDialogState extends State<MathChallengeDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late int _num1;
  late int _num2;
  late bool _isAddition;
  late int _correctAnswer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _generateProblem();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _generateProblem() {
    final random = Random();
    // Option 2: Clean 2-digit mental addition/subtraction (num1 +/- num2)
    // Fast, natural, zero multiplication needed.
    _isAddition = random.nextBool();
    if (_isAddition) {
      _num1 = 25 + random.nextInt(45); // 25 to 69
      _num2 = 14 + random.nextInt(35); // 14 to 48
      _correctAnswer = _num1 + _num2;
    } else {
      _num1 = 50 + random.nextInt(45); // 50 to 94 (larger first)
      _num2 = 15 + random.nextInt(35); // 15 to 49 (smaller second, always positive)
      _correctAnswer = _num1 - _num2;
    }
    _controller.clear();
    _errorMessage = null;
  }

  void _verify() {
    final entered = int.tryParse(_controller.text.trim());
    if (entered == null) {
      setState(() => _errorMessage = 'Please enter a number');
      return;
    }

    if (entered == _correctAnswer) {
      Navigator.of(context).pop();
      widget.onSolved();
    } else {
      setState(() {
        _errorMessage = 'Incorrect answer. Try this new one.';
        _generateProblem();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final operatorSign = _isAddition ? '+' : '−';
    final problemText = '$_num1 $operatorSign $_num2 = ?';

    return AlertDialog(
      backgroundColor: AppTheme.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppTheme.cardBorder),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.warningAmber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.calculate_outlined, color: AppTheme.warningAmber, size: 22),
          ),
          const SizedBox(width: 12),
          Text(
            widget.title,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Solve this quick calculation to ${widget.actionDescription}:',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Center(
                child: Text(
                  problemText,
                  style: const TextStyle(
                    color: AppTheme.mint,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'Enter answer',
                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                filled: true,
                fillColor: AppTheme.background,
                errorText: _errorMessage,
                errorStyle: const TextStyle(color: AppTheme.glitchCoral, fontSize: 11),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.mint, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _verify(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.mint,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          onPressed: _verify,
          child: const Text('Verify & Unlock', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

