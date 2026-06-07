import 'package:flutter/material.dart';

/// الأيام المتاحة للجلسات: الأحد إلى الأربعاء
const List<String> kSessionDays = [
  'sunday',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
];

const Map<String, String> kDayLabels = {
  'sunday': 'الأحد',
  'monday': 'الاثنين',
  'tuesday': 'الثلاثاء',
  'wednesday': 'الأربعاء',
  'thursday': 'الخميس',
};

/// Widget لاختيار أيام الجلسات. يعرض 4 أيام كـ Chips.
/// [maxDays]: الحد الأقصى لعدد الأيام القابلة للاختيار.
/// [selectedDays]: الأيام المختارة حالياً.
/// [onChanged]: callback عند تغيير الاختيار.
class DayPickerWidget extends StatelessWidget {
  final List<String> selectedDays;
  final int maxDays;
  final ValueChanged<List<String>> onChanged;

  const DayPickerWidget({
    super.key,
    required this.selectedDays,
    required this.maxDays,
    required this.onChanged,
  });

  void _toggle(String day) {
    final updated = List<String>.from(selectedDays);
    if (updated.contains(day)) {
      updated.remove(day);
    } else {
      if (updated.length < maxDays) {
        updated.add(day);
      }
    }
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final reachedMax = selectedDays.length >= maxDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'أيام الجلسات المفضلة',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              '${selectedDays.length}/$maxDays',
              style: TextStyle(
                fontSize: 12,
                color: reachedMax ? Colors.teal : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: kSessionDays.map((day) {
            final isSelected = selectedDays.contains(day);
            final isDisabled = !isSelected && reachedMax;

            return FilterChip(
              label: Text(kDayLabels[day]!),
              selected: isSelected,
              onSelected: isDisabled ? null : (_) => _toggle(day),
              selectedColor: const Color(0xFF0F766E).withValues(alpha: 0.15),
              checkmarkColor: const Color(0xFF0F766E),
              labelStyle: TextStyle(
                color: isSelected
                    ? const Color(0xFF0F766E)
                    : isDisabled
                        ? Colors.grey.shade400
                        : null,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF0F766E)
                    : isDisabled
                        ? Colors.grey.shade300
                        : Colors.grey.shade400,
              ),
            );
          }).toList(),
        ),
        if (reachedMax)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'وصلت للحد الأقصى ($maxDays أيام)',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }
}
