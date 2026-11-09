import 'package:flutter/material.dart';
import '../utils/app_labels.dart';

/// مستوى الطالب كما يُرسل للسيرفر:
/// تحفيظ = عدد الأجزاء المحفوظة (0–30) + قراءة واحدة
/// قراءات = إفراد (قراءة واحدة) أو جمع (قراءتان فأكثر)
class StudentLevelValue {
  final String level; // tahfeez | qiraat
  final int? memorizedParts;
  final String? qiraatMode; // ifrad | jam
  final String reading; // للتحفيظ والإفراد
  final List<String> readings; // للجمع

  const StudentLevelValue({
    this.level = 'tahfeez',
    this.memorizedParts,
    this.qiraatMode,
    this.reading = 'hafs_an_asim',
    this.readings = const [],
  });

  bool get isJam => level == 'qiraat' && qiraatMode == 'jam';

  /// من بيانات الطالب المخزنة (تعديل الحساب). القيم القديمة تُعامل كتحفيظ بلا عدد.
  factory StudentLevelValue.fromMap(Map extra) {
    final level = extra['level']?.toString() == 'qiraat' ||
            extra['level']?.toString() == 'new_reading'
        ? 'qiraat'
        : 'tahfeez';
    final mode = extra['qiraat_mode']?.toString();
    final list = (extra['reading_type']?.toString() ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final isJam = level == 'qiraat' && mode == 'jam';
    return StudentLevelValue(
      level: level,
      memorizedParts: int.tryParse(extra['memorized_parts']?.toString() ?? ''),
      qiraatMode: (mode == 'ifrad' || mode == 'jam') ? mode : null,
      reading: (!isJam && list.isNotEmpty) ? list.first : 'hafs_an_asim',
      readings: isJam ? list : const [],
    );
  }

  StudentLevelValue copyWith({
    String? level,
    int? memorizedParts,
    String? qiraatMode,
    String? reading,
    List<String>? readings,
  }) {
    return StudentLevelValue(
      level: level ?? this.level,
      memorizedParts: memorizedParts ?? this.memorizedParts,
      qiraatMode: qiraatMode ?? this.qiraatMode,
      reading: reading ?? this.reading,
      readings: readings ?? this.readings,
    );
  }

  Map<String, dynamic> toPayload() => {
        'level': level,
        if (level == 'tahfeez') 'memorized_parts': memorizedParts,
        if (level == 'qiraat') 'qiraat_mode': qiraatMode,
        'reading_type': isJam ? readings.join(',') : reading,
      };
}

class StudentLevelFields extends StatelessWidget {
  final StudentLevelValue value;
  final ValueChanged<StudentLevelValue> onChanged;
  final bool enabled;

  const StudentLevelFields({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: value.level,
          isExpanded: true,
          decoration: _decoration('المستوى'),
          items: const [
            DropdownMenuItem(value: 'tahfeez', child: Text('تحفيظ')),
            DropdownMenuItem(value: 'qiraat', child: Text('قراءات')),
          ],
          onChanged: enabled
              ? (v) {
                  if (v != null) onChanged(value.copyWith(level: v));
                }
              : null,
        ),
        const SizedBox(height: 12),
        if (value.level == 'tahfeez') ...[
          DropdownButtonFormField<int>(
            key: const ValueKey('memorized_parts'),
            initialValue: value.memorizedParts,
            isExpanded: true,
            menuMaxHeight: 360,
            decoration: _decoration('عدد الأجزاء التي تحفظها'),
            items: List.generate(
              31,
              (i) => DropdownMenuItem(value: i, child: Text('$i')),
            ),
            validator: (v) => v == null ? 'اختر عدد الأجزاء' : null,
            onChanged: enabled
                ? (v) {
                    if (v != null) onChanged(value.copyWith(memorizedParts: v));
                  }
                : null,
          ),
          const SizedBox(height: 12),
          _singleReading(),
        ] else ...[
          FormField<String>(
            key: const ValueKey('qiraat_mode'),
            initialValue: value.qiraatMode,
            validator: (_) =>
                value.qiraatMode == null ? 'اختر إفراد أو جمع' : null,
            builder: (field) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ifrad', label: Text('إفراد')),
                    ButtonSegment(value: 'jam', label: Text('جمع')),
                  ],
                  emptySelectionAllowed: true,
                  selected: {
                    if (value.qiraatMode != null) value.qiraatMode!,
                  },
                  onSelectionChanged: enabled
                      ? (s) {
                          if (s.isEmpty) return;
                          field.didChange(s.first);
                          onChanged(value.copyWith(qiraatMode: s.first));
                        }
                      : null,
                ),
                if (field.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 12),
                    child: Text(
                      field.errorText!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (value.qiraatMode == 'ifrad') _singleReading(),
          if (value.qiraatMode == 'jam') _multiReadings(context),
        ],
      ],
    );
  }

  Widget _singleReading() {
    return DropdownButtonFormField<String>(
      key: const ValueKey('single_reading'),
      initialValue: value.reading,
      isExpanded: true,
      menuMaxHeight: 420,
      decoration: _decoration('القراءة المطلوبة'),
      items: AppLabels.qiraatList()
          .map((q) => DropdownMenuItem(
                value: q,
                child: Text(AppLabels.qiraa(q), overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: enabled
          ? (v) {
              if (v != null) onChanged(value.copyWith(reading: v));
            }
          : null,
    );
  }

  Widget _multiReadings(BuildContext context) {
    return FormField<List<String>>(
      key: const ValueKey('multi_readings'),
      validator: (_) =>
          value.readings.length < 2 ? 'اختر قراءتين على الأقل للجمع' : null,
      builder: (field) => InputDecorator(
        decoration: _decoration('القراءات التي ستجمعها').copyWith(
          errorText: field.errorText,
        ),
        child: Column(
          children: AppLabels.qiraatList().map((q) {
            return CheckboxListTile(
              value: value.readings.contains(q),
              onChanged: enabled
                  ? (checked) {
                      // بترتيب القائمة الثابت حتى تُعرض القراءات بنفس الترتيب دائمًا
                      final next = AppLabels.qiraatList()
                          .where((r) => r == q
                              ? checked == true
                              : value.readings.contains(r))
                          .toList();
                      field.didChange(next);
                      onChanged(value.copyWith(readings: next));
                    }
                  : null,
              title: Text(AppLabels.qiraa(q),
                  style: const TextStyle(height: 1.35)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            );
          }).toList(),
        ),
      ),
    );
  }
}
