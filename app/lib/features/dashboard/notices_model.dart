// Notices model — mirrors GET /student/notices.

String? _strN(dynamic v) => v?.toString();

class Notice {
  final String? noticeId;
  final String? title;
  final String? description;
  final String? type;
  final String? postedBy;
  final String? postedDate;
  final String? filePath;

  const Notice({
    this.noticeId,
    this.title,
    this.description,
    this.type,
    this.postedBy,
    this.postedDate,
    this.filePath,
  });

  /// UCAM dates come as "/Date(1719000000000)/"; format to a short date, else
  /// return the raw string.
  String get when {
    final raw = postedDate ?? '';
    final m = RegExp(r'/Date\((\d+)').firstMatch(raw);
    if (m != null) {
      final ms = int.tryParse(m.group(1)!);
      if (ms != null) {
        final d = DateTime.fromMillisecondsSinceEpoch(ms);
        return '${d.day}/${d.month}/${d.year}';
      }
    }
    return raw;
  }

  factory Notice.fromJson(Map<String, dynamic> j) => Notice(
        noticeId: _strN(j['notice_id']),
        title: _strN(j['title']),
        description: _strN(j['description']),
        type: _strN(j['type']),
        postedBy: _strN(j['posted_by']),
        postedDate: _strN(j['posted_date']),
        filePath: _strN(j['file_path']),
      );

  Map<String, dynamic> toJson() => {
        'notice_id': noticeId,
        'title': title,
        'description': description,
        'type': type,
        'posted_by': postedBy,
        'posted_date': postedDate,
        'file_path': filePath,
      };
}

class NoticesData {
  final List<Notice> notices;
  const NoticesData({this.notices = const []});

  factory NoticesData.fromJson(Map<String, dynamic> j) => NoticesData(
        notices: ((j['notices'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Notice.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toJson() =>
      {'notices': notices.map((e) => e.toJson()).toList()};
}
