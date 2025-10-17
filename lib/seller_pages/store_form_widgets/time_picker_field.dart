// lib/seller_pages/store_form_widgets/time_picker_field.dart
import 'package:flutter/material.dart';
import '../../components/app_colors.dart';

class TimePickerField extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final VoidCallback onTap;

  const TimePickerField(
      {super.key, required this.label, required this.time, required this.onTap});

  // --- ADDED: Helper to format TimeOfDay into a 12-hour AM/PM string ---
  String _formatTime(BuildContext context, TimeOfDay? time) {
    if (time == null) {
      return 'Select Time';
    }
    // Use the built-in format method which respects device settings (usually AM/PM)
    return time.format(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.textSecondary.withAlpha(127)),
              borderRadius: BorderRadius.circular(12),
              color: AppColors.backgroundColor,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  // --- MODIFIED: Use the new formatting logic ---
                  _formatTime(context, time),
                  style: TextStyle(
                    color: time == null
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
                const Icon(Icons.access_time, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}