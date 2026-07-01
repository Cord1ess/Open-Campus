// UIU public notices model — mirrors GET /calendar/notices/uiu?page=N.

String? _strN(dynamic v) => v?.toString();
int _intN(dynamic v, [int fallback = 1]) =>
    v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? fallback : fallback);

class UiuNotice {
  final String title;
  final String url;
  final String? dateText;
  const UiuNotice({required this.title, required this.url, this.dateText});

  factory UiuNotice.fromJson(Map<String, dynamic> j) => UiuNotice(
        title: _strN(j['title']) ?? '',
        url: _strN(j['url']) ?? '',
        dateText: _strN(j['date_text']),
      );
}

class UiuNoticesData {
  final List<UiuNotice> notices;
  final int page;
  final int totalPages;
  const UiuNoticesData({
    this.notices = const [],
    this.page = 1,
    this.totalPages = 1,
  });

  factory UiuNoticesData.fromJson(Map<String, dynamic> j) => UiuNoticesData(
        notices: ((j['notices'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => UiuNotice.fromJson(e.cast<String, dynamic>()))
            .toList(),
        page: _intN(j['page']),
        totalPages: _intN(j['total_pages']),
      );
}
