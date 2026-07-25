import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PasscodeMode { setup, verify, disable }

class PasscodeScreen extends StatefulWidget {
  final PasscodeMode mode;
  final VoidCallback? onSuccess;

  const PasscodeScreen({
    super.key,
    required this.mode,
    this.onSuccess,
  });

  @override
  State<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends State<PasscodeScreen> {
  String _enteredCode = '';
  String _firstSetupCode = '';
  String _errorMessage = '';
  bool _isConfirming = false;

  void _onNumberPressed(int number) {
    if (_enteredCode.length >= 4) return;
    setState(() {
      _errorMessage = '';
      _enteredCode += number.toString();
    });

    if (_enteredCode.length == 4) {
      Future.delayed(const Duration(milliseconds: 150), _processPasscode);
    }
  }

  void _onDeletePressed() {
    if (_enteredCode.isEmpty) return;
    setState(() {
      _errorMessage = '';
      _enteredCode = _enteredCode.substring(0, _enteredCode.length - 1);
    });
  }

  Future<void> _processPasscode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString('app_passcode');

    switch (widget.mode) {
      case PasscodeMode.verify:
        if (_enteredCode == savedCode) {
          if (widget.onSuccess != null) {
            widget.onSuccess!();
          } else {
            if (mounted) {
              Navigator.pop(context, true);
            }
          }
        } else {
          _triggerError('Incorrect passcode');
        }
        break;

      case PasscodeMode.setup:
        if (!_isConfirming) {
          setState(() {
            _firstSetupCode = _enteredCode;
            _enteredCode = '';
            _isConfirming = true;
          });
        } else {
          if (_enteredCode == _firstSetupCode) {
            await prefs.setString('app_passcode', _enteredCode);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Passcode enabled successfully')),
              );
              Navigator.pop(context, true);
            }
          } else {
            setState(() {
              _firstSetupCode = '';
              _isConfirming = false;
            });
            _triggerError('Passcodes do not match. Start over.');
          }
        }
        break;

      case PasscodeMode.disable:
        if (_enteredCode == savedCode) {
          await prefs.remove('app_passcode');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Passcode disabled')),
            );
            Navigator.pop(context, true);
          }
        } else {
          _triggerError('Incorrect passcode');
        }
        break;
    }
  }

  void _triggerError(String msg) {
    setState(() {
      _errorMessage = msg;
      _enteredCode = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String titleText = 'Enter Passcode';
    String subtitleText = 'Access your private notes';

    if (widget.mode == PasscodeMode.setup) {
      if (_isConfirming) {
        titleText = 'Confirm Passcode';
        subtitleText = 'Re-enter your 4-digit code';
      } else {
        titleText = 'Set Passcode';
        subtitleText = 'Create a 4-digit code to lock notes';
      }
    } else if (widget.mode == PasscodeMode.disable) {
      titleText = 'Disable Lock';
      subtitleText = 'Enter current passcode to remove lock';
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: widget.mode != PasscodeMode.verify
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context, false),
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Icon(
              widget.mode == PasscodeMode.verify ? Icons.lock_outline : Icons.security_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              titleText,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitleText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 36),

            // Passcode dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final filled = index < _enteredCode.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withValues(alpha: 0.15),
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Error display
            SizedBox(
              height: 20,
              child: Text(
                _errorMessage,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const Spacer(),

            // Keypad Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
              child: Column(
                children: [
                  _buildKeypadRow([1, 2, 3]),
                  const SizedBox(height: 16),
                  _buildKeypadRow([4, 5, 6]),
                  const SizedBox(height: 16),
                  _buildKeypadRow([7, 8, 9]),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      widget.mode != PasscodeMode.verify
                          ? _buildActionButton('Cancel', () => Navigator.pop(context, false))
                          : const SizedBox(width: 68, height: 68),
                      _buildNumberButton(0),
                      _buildActionButtonIcon(Icons.backspace_outlined, _onDeletePressed),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<int> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: numbers.map((n) => _buildNumberButton(n)).toList(),
    );
  }

  Widget _buildNumberButton(int number) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.grey[900] : Colors.grey[100],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _onNumberPressed(number),
          child: Center(
            child: Text(
              number.toString(),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: 68,
      height: 68,
      child: TextButton(
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtonIcon(IconData icon, VoidCallback onPressed) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 68,
      height: 68,
      child: IconButton(
        icon: Icon(icon, color: theme.colorScheme.primary),
        onPressed: onPressed,
      ),
    );
  }
}
