import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';

class ParentPinDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool isSetupMode;
  final bool isPinResetOnly;
  final VoidCallback onSuccess;

  const ParentPinDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isSetupMode,
    this.isPinResetOnly = false,
    required this.onSuccess,
  });

  static const List<String> securityQuestions = [
    "What was the brand of your first phone?",
    "What was your childhood nickname?",
    "Who was your childhood best friend?",
    "What was the name of your first school?",
    "What is your favorite childhood food?",
  ];

  /// If a Parent PIN is already saved, prompts to verify it; otherwise prompts to create one + recovery question first.
  static Future<void> ensurePinAndRun({
    required BuildContext context,
    required String actionDescription,
    required VoidCallback onSuccess,
    bool requireVerificationIfAlreadySet = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('parent_pin_code') ?? '';
    final savedAnswer = (prefs.getString('parent_security_answer') ?? '').trim();

    if (!context.mounted) return;

    if (savedPin.length != 4 || savedAnswer.isEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => ParentPinDialog(
          title: 'Set 4-Digit Parent PIN',
          subtitle:
              'Create a secret 4-digit PIN to $actionDescription. Your child will not be able to turn Kids Mode off without this PIN.',
          isSetupMode: true,
          onSuccess: onSuccess,
        ),
      );
    } else if (requireVerificationIfAlreadySet) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => ParentPinDialog(
          title: 'Parent PIN Required',
          subtitle: 'Enter your 4-digit Parent PIN to $actionDescription.',
          isSetupMode: false,
          onSuccess: onSuccess,
        ),
      );
    } else {
      onSuccess();
    }
  }

  /// Prompts the parent to change/reset their 4-digit PIN and security question.
  static Future<void> showChangePin({
    required BuildContext context,
    required VoidCallback onPinUpdated,
    bool pinOnly = false,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ParentPinDialog(
        title: 'Set New 4-Digit Parent PIN',
        subtitle: 'Enter a new 4-digit Parent PIN for Kids Mode.',
        isSetupMode: true,
        isPinResetOnly: pinOnly,
        onSuccess: onPinUpdated,
      ),
    );
  }

  @override
  State<ParentPinDialog> createState() => _ParentPinDialogState();
}

class _ParentPinDialogState extends State<ParentPinDialog> {
  String _enteredPin = '';
  String _savedPin = '';
  String _savedQuestion = ParentPinDialog.securityQuestions.first;
  String _savedAnswer = '';

  bool _hasError = false;
  String _errorMessage = '';

  // Sub-views inside the dialog:
  // 0 = PIN keypad, 1 = Setup Security Question (after entering 4-digit PIN in setup mode), 2 = Verify Security Question (Forgot PIN)
  int _dialogStep = 0;

  String _selectedQuestion = ParentPinDialog.securityQuestions.first;
  final TextEditingController _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _savedPin = prefs.getString('parent_pin_code') ?? '';
        _savedQuestion = prefs.getString('parent_security_question') ??
            ParentPinDialog.securityQuestions.first;
        _savedAnswer = (prefs.getString('parent_security_answer') ?? '').trim();
        _selectedQuestion =
            ParentPinDialog.securityQuestions.contains(_savedQuestion)
                ? _savedQuestion
                : ParentPinDialog.securityQuestions.first;
      });
    }
  }

  void _onDigitTap(String digit) {
    if (_enteredPin.length >= 4) return;
    HapticFeedback.lightImpact();
    setState(() {
      _enteredPin += digit;
      _hasError = false;
      _errorMessage = '';
    });

    if (_enteredPin.length == 4) {
      _handlePinComplete();
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _hasError = false;
      _errorMessage = '';
    });
  }

  Future<void> _handlePinComplete() async {
    if (widget.isSetupMode) {
      if (widget.isPinResetOnly && _savedAnswer.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('parent_pin_code', _enteredPin);
        if (mounted) {
          Navigator.of(context).pop();
          widget.onSuccess();
        }
      } else {
        // Move to Step 1: Set Parent Security Question & Secret Answer
        setState(() {
          _dialogStep = 1;
          _hasError = false;
          _errorMessage = '';
        });
      }
    } else {
      if (_enteredPin == _savedPin) {
        if (mounted) {
          Navigator.of(context).pop();
          widget.onSuccess();
        }
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _hasError = true;
          _errorMessage = 'Incorrect Parent PIN. Try again.';
          _enteredPin = '';
        });
      }
    }
  }

  Future<void> _savePinAndSecurityQuestion() async {
    final answer = _answerController.text.trim();
    if (answer.length < 2) {
      HapticFeedback.heavyImpact();
      setState(() {
        _hasError = true;
        _errorMessage = 'Please enter a secret answer (at least 2 characters).';
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('parent_pin_code', _enteredPin);
    await prefs.setString('parent_security_question', _selectedQuestion);
    await prefs.setString('parent_security_answer', answer.toLowerCase());

    if (mounted) {
      Navigator.of(context).pop();
      widget.onSuccess();
    }
  }

  void _onForgotPinTap() {
    setState(() {
      _dialogStep = 2;
      _answerController.clear();
      _hasError = false;
      _errorMessage = '';
    });
  }

  void _verifyRecoveryAnswer() {
    final entered = _answerController.text.trim().toLowerCase();
    if (entered.isEmpty || entered != _savedAnswer.toLowerCase()) {
      HapticFeedback.heavyImpact();
      setState(() {
        _hasError = true;
        _errorMessage = 'Incorrect security answer. Try again.';
      });
      return;
    }

    Navigator.of(context).pop();
    ParentPinDialog.showChangePin(
      context: context,
      pinOnly: true,
      onPinUpdated: widget.onSuccess,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: AppTheme.cardBorder, width: 1.5),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: _dialogStep == 0
            ? _buildPinKeypadView()
            : (_dialogStep == 1
                ? _buildSetupSecurityQuestionView()
                : _buildVerifySecurityQuestionView()),
      ),
    );
  }

  Widget _buildPinKeypadView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cyan.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_outline, color: AppTheme.cyan, size: 28),
        ),
        const SizedBox(height: 14),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),

        // 4 PIN Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final isFilled = index < _enteredPin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _hasError
                    ? AppTheme.glitchCoral
                    : (isFilled ? AppTheme.cyan : AppTheme.background),
                border: Border.all(
                  color: _hasError
                      ? AppTheme.glitchCoral
                      : (isFilled ? AppTheme.cyan : AppTheme.cardBorder),
                  width: 2,
                ),
              ),
            );
          }),
        ),
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.glitchCoral,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 20),

        // Numeric Keypad
        _buildKeypadRow(['1', '2', '3']),
        const SizedBox(height: 10),
        _buildKeypadRow(['4', '5', '6']),
        const SizedBox(height: 10),
        _buildKeypadRow(['7', '8', '9']),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ),
            _buildDigitButton('0'),
            IconButton(
              onPressed: _onBackspace,
              icon: const Icon(Icons.backspace_outlined, color: AppTheme.textPrimary, size: 22),
            ),
          ],
        ),

        if (!widget.isSetupMode) ...[
          const SizedBox(height: 6),
          TextButton(
            onPressed: _onForgotPinTap,
            child: const Text(
              'Forgot PIN? Answer Security Question',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11.5,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSetupSecurityQuestionView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.mint.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user_outlined, color: AppTheme.mint, size: 26),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Parent Recovery Question',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Choose a security question only you know so your child cannot reset your PIN if you forget it.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.38,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'SECURITY QUESTION',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedQuestion,
              isExpanded: true,
              dropdownColor: AppTheme.surfaceCard,
              icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.cyan),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              items: ParentPinDialog.securityQuestions.map((q) {
                return DropdownMenuItem<String>(
                  value: q,
                  child: Text(q, maxLines: 2, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedQuestion = val);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'YOUR SECRET ANSWER',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _answerController,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter secret answer...',
            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            filled: true,
            fillColor: AppTheme.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.mint, width: 1.5),
            ),
          ),
          onChanged: (_) {
            if (_hasError) {
              setState(() {
                _hasError = false;
                _errorMessage = '';
              });
            }
          },
        ),
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: const TextStyle(
              color: AppTheme.glitchCoral,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mint,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _savePinAndSecurityQuestion,
            child: const Text(
              'Save Parent PIN & Question',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerifySecurityQuestionView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.warningAmber.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.help_outline_rounded, color: AppTheme.warningAmber, size: 26),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Recover Parent PIN',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Answer your secret Parent Security Question to set a new 4-digit PIN.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.38,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Text(
            _savedQuestion,
            style: const TextStyle(
              color: AppTheme.cyan,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _answerController,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Your secret answer...',
            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            filled: true,
            fillColor: AppTheme.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.cyan, width: 1.5),
            ),
          ),
          onChanged: (_) {
            if (_hasError) {
              setState(() {
                _hasError = false;
                _errorMessage = '';
              });
            }
          },
        ),
        if (_errorMessage.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: const TextStyle(
              color: AppTheme.glitchCoral,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.cardBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  setState(() {
                    _dialogStep = 0;
                    _hasError = false;
                    _errorMessage = '';
                  });
                },
                child: const Text('Back to PIN', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.mint,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _verifyRecoveryAnswer,
                child: const Text('Verify & Reset', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map(_buildDigitButton).toList(),
    );
  }

  Widget _buildDigitButton(String digit) {
    return InkWell(
      borderRadius: BorderRadius.circular(32),
      onTap: () => _onDigitTap(digit),
      child: Container(
        width: 60,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Text(
          digit,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
