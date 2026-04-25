class AppLabels {
  static String status(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'pending':
        return 'قيد المراجعة';
      case 'approved':
        return 'معتمد';
      case 'rejected':
        return 'مرفوض';
      case 'started':
        return 'نشطة';
      case 'ended':
        return 'منتهية';
      case 'cancelled':
        return 'ملغاة';
      case 'present':
        return 'حاضر';
      case 'absent':
        return 'غائب';
      default:
        return value ?? '';
    }
  }

  static String level(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'beginner':
        return 'مبتدئ';
      case 'intermediate':
        return 'متوسط';
      case 'advanced':
        return 'متقدم';
      case 'new_reading':
        return 'قراءة جديدة';
      default:
        return value ?? '';
    }
  }

  static String sessionType(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'individual':
        return 'فردية';
      case 'group':
        return 'جماعية';
      default:
        return value ?? '';
    }
  }

  static String targetType(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'student':
        return 'طالب';
      case 'students':
        return 'طلاب';
      case 'teacher':
        return 'مُقرئ';
      case 'teachers':
        return 'مُقرئون';
      case 'all':
        return 'الجميع';
      default:
        return value ?? '';
    }
  }

  static String gender(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'male':
        return 'ذكر';
      case 'female':
        return 'أنثى';
      default:
        return value ?? '';
    }
  }

  static String period(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'after_fajr':
        return 'بعد الفجر';
      case 'after_dhuhr':
        return 'بعد الظهر';
      case 'after_asr':
        return 'بعد العصر';
      case 'after_maghrib':
        return 'بعد المغرب';
      case 'after_isha':
        return 'بعد العشاء';
      default:
        return value ?? '';
    }
  }

  static List<String> periodsList() {
    return [
      'after_fajr',
      'after_dhuhr',
      'after_asr',
      'after_maghrib',
      'after_isha',
    ];
  }

  static String periodsText(dynamic raw) {
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) return '—';

    final parts = text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map(period)
        .toList();

    if (parts.isEmpty) return '—';
    return parts.join('، ');
  }

  static List<String> qiraatList() {
    return [
      'qalun_an_nafi',
      'warsh_an_nafi',
      'al_bazzi_an_ibn_kathir',
      'qunbul_an_ibn_kathir',
      'al_duri_an_abi_amr',
      'al_susi_an_abi_amr',
      'hisham_an_ibn_amir',
      'ibn_dhakwan_an_ibn_amir',
      'shuba_an_asim',
      'hafs_an_asim',
      'khalaf_an_hamzah',
      'khallad_an_hamzah',
      'abu_al_harith_an_al_kisai',
      'al_duri_an_al_kisai',
      'ibn_wardan_an_abi_jafar',
      'ibn_jammaz_an_abi_jafar',
      'ruways_an_yaqub',
      'rawh_an_yaqub',
      'ishaq_an_khalaf',
      'idris_an_khalaf',
    ];
  }

  static String qiraa(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'all_qiraat':
        return 'جميع القراءات';
      case 'qalun_an_nafi':
        return 'قالون عن نافع';
      case 'warsh_an_nafi':
        return 'ورش عن نافع';
      case 'al_bazzi_an_ibn_kathir':
        return 'البزي عن ابن كثير';
      case 'qunbul_an_ibn_kathir':
        return 'قنبل عن ابن كثير';
      case 'al_duri_an_abi_amr':
        return 'الدوري عن أبو عمرو';
      case 'al_susi_an_abi_amr':
        return 'السوسي عن أبو عمرو';
      case 'hisham_an_ibn_amir':
        return 'هشام عن ابن عامر';
      case 'ibn_dhakwan_an_ibn_amir':
        return 'ابن ذكوان عن ابن عامر';
      case 'shuba_an_asim':
        return 'شعبة عن عاصم';
      case 'hafs_an_asim':
        return 'حفص عن عاصم';
      case 'khalaf_an_hamzah':
        return 'خلف عن حمزة';
      case 'khallad_an_hamzah':
        return 'خلاد عن حمزة';
      case 'abu_al_harith_an_al_kisai':
        return 'أبو الحارث عن الكسائي';
      case 'al_duri_an_al_kisai':
        return 'الدوري عن الكسائي';
      case 'ibn_wardan_an_abi_jafar':
        return 'ابن وردان عن أبو جعفر';
      case 'ibn_jammaz_an_abi_jafar':
        return 'ابن جماز عن أبو جعفر';
      case 'ruways_an_yaqub':
        return 'رويس عن يعقوب';
      case 'rawh_an_yaqub':
        return 'روح عن يعقوب';
      case 'ishaq_an_khalaf':
        return 'إسحاق عن خلف';
      case 'idris_an_khalaf':
        return 'إدريس عن خلف';
      default:
        return value ?? '';
    }
  }

  static String qiraatText(dynamic raw) {
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) return '—';

    final parts = text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map(qiraa)
        .toList();

    if (parts.isEmpty) return '—';
    return parts.join('، ');
  }

  static String yesNo(bool value) => value ? 'نعم' : 'لا';
}