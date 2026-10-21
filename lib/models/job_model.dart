class JobModel {
  final String id;
  final String title;
  final String company;
  final String companyLogo;
  final String location;
  final String jobType;
  final String category;
  final String description;
  final String rawDescription;
  final String url;
  final List<String> tags;
  final String salary;
  final String publishedAt;
  final bool isSaved;
  final DateTime? savedAt;

  JobModel({
    required this.id,
    required this.title,
    required this.company,
    this.companyLogo = '',
    required this.location,
    this.jobType = 'Full-time',
    this.category = 'Software Development',
    required this.description,
    this.rawDescription = '',
    required this.url,
    this.tags = const [],
    this.salary = '',
    this.publishedAt = '',
    this.isSaved = false,
    this.savedAt,
  });

  /// Strips HTML tags and unescapes entities for clean mobile rendering.
  static String stripHtml(String htmlString) {
    if (htmlString.isEmpty) return '';
    String text = htmlString.replaceAll(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      '\n',
    );
    text = text.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp(r'</li>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    text = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
    // Collapse multiple blank lines
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  factory JobModel.fromJson(Map<String, dynamic> json) {
    final rawDesc = (json['description'] ?? '').toString();
    final cleanDesc = stripHtml(rawDesc);

    // Parse tags safely from Remotive JSON or List
    List<String> parsedTags = [];
    if (json['tags'] is List) {
      parsedTags = (json['tags'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final String jobId = (json['id'] ?? '').toString().isNotEmpty
        ? json['id'].toString()
        : (json['url'] ?? '').toString().hashCode.abs().toString();

    String formattedJobType = (json['job_type'] ?? 'Full-time').toString();
    if (formattedJobType.contains('_')) {
      formattedJobType = formattedJobType
          .split('_')
          .map(
            (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '',
          )
          .join(' ');
    }

    return JobModel(
      id: jobId,
      title: json['title'] ?? 'Untitled Position',
      company: json['company_name'] ?? json['company'] ?? 'Unknown Company',
      companyLogo: json['company_logo'] ?? '',
      location:
          json['candidate_required_location'] ?? json['location'] ?? 'Remote',
      jobType: formattedJobType,
      category: json['category'] ?? 'Software Development',
      description: cleanDesc,
      rawDescription: rawDesc,
      url: json['url'] ?? '',
      tags: parsedTags,
      salary: json['salary'] ?? '',
      publishedAt: json['publication_date'] ?? '',
      isSaved: json['isSaved'] == true,
      savedAt: json['savedAt'] != null
          ? DateTime.tryParse(json['savedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'company': company,
      'companyLogo': companyLogo,
      'location': location,
      'jobType': jobType,
      'category': category,
      'description': description,
      'rawDescription': rawDescription,
      'url': url,
      'tags': tags,
      'salary': salary,
      'publishedAt': publishedAt,
      'isSaved': isSaved,
      'savedAt': savedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory JobModel.fromMap(Map<String, dynamic> map) {
    return JobModel.fromJson(map);
  }

  JobModel copyWith({
    String? id,
    String? title,
    String? company,
    String? companyLogo,
    String? location,
    String? jobType,
    String? category,
    String? description,
    String? rawDescription,
    String? url,
    List<String>? tags,
    String? salary,
    String? publishedAt,
    bool? isSaved,
    DateTime? savedAt,
  }) {
    return JobModel(
      id: id ?? this.id,
      title: title ?? this.title,
      company: company ?? this.company,
      companyLogo: companyLogo ?? this.companyLogo,
      location: location ?? this.location,
      jobType: jobType ?? this.jobType,
      category: category ?? this.category,
      description: description ?? this.description,
      rawDescription: rawDescription ?? this.rawDescription,
      url: url ?? this.url,
      tags: tags ?? this.tags,
      salary: salary ?? this.salary,
      publishedAt: publishedAt ?? this.publishedAt,
      isSaved: isSaved ?? this.isSaved,
      savedAt: savedAt ?? this.savedAt,
    );
  }
}
