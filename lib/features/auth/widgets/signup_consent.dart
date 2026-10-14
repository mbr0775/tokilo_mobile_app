import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// One aligned consent control, with independently accessible policy links.
class SignupConsent extends StatelessWidget {
  const SignupConsent({
    super.key,
    required this.accepted,
    required this.onChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final bool accepted;
  final ValueChanged<bool>? onChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Checkbox(
                value: accepted,
                semanticLabel: 'Accept Privacy Policy and Terms & Conditions',
                activeColor: AppColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                shape: const CircleBorder(),
                onChanged: onChanged == null
                    ? null
                    : (value) => onChanged!(value ?? false),
              ),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onChanged == null ? null : () => onChanged!(!accepted),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'I accept the Privacy Policy and Terms & Conditions.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 48),
          child: Wrap(
            spacing: 12,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: onOpenPrivacy,
                child: const Text(
                  'Privacy Policy',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: onOpenTerms,
                child: const Text(
                  'Terms & Conditions',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
