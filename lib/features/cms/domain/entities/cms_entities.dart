import '../../../../core/utils/db_parsing.dart';

/// A Home hero banner (`public.cms_banners`). [imageUrl] is resolved from
/// [imagePath] (public `cms-media` bucket) by the data layer.
class CmsBanner {
  const CmsBanner({
    required this.id,
    required this.title,
    this.subtitle,
    this.imagePath,
    this.imageUrl,
    this.link,
    this.sortOrder = 0,
    this.isActive = true,
    this.startsAt,
    this.endsAt,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? imagePath;
  final String? imageUrl;

  /// In-app route, e.g. `/explore?material=Gold`.
  final String? link;
  final int sortOrder;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt;

  factory CmsBanner.fromMap(Map<String, dynamic> map, {String? imageUrl}) =>
      CmsBanner(
        id: map['id'] as String,
        title: map['title'] as String,
        subtitle: map['subtitle'] as String?,
        imagePath: map['image_path'] as String?,
        imageUrl: imageUrl,
        link: map['link'] as String?,
        sortOrder: parseInt(map['sort_order']),
        isActive: map['is_active'] as bool? ?? true,
        startsAt: parseTimestamp(map['starts_at']),
        endsAt: parseTimestamp(map['ends_at']),
      );
}

/// FAQ entry or policy/info page (`public.cms_pages`). For FAQs the [title] is
/// the question and [body] the answer.
class CmsPage {
  const CmsPage({
    required this.id,
    required this.slug,
    required this.kind,
    required this.title,
    this.body = '',
    this.sortOrder = 0,
    this.isPublished = true,
    this.updatedAt,
  });

  final String id;
  final String slug;
  final String kind;
  final String title;
  final String body;
  final int sortOrder;
  final bool isPublished;
  final DateTime? updatedAt;

  static const faq = 'faq';
  static const policy = 'policy';
  static const info = 'info';
  static const kinds = {faq: 'FAQ', policy: 'Policy', info: 'Info page'};

  factory CmsPage.fromMap(Map<String, dynamic> map) => CmsPage(
    id: map['id'] as String,
    slug: map['slug'] as String,
    kind: map['kind'] as String,
    title: map['title'] as String,
    body: map['body'] as String? ?? '',
    sortOrder: parseInt(map['sort_order']),
    isPublished: map['is_published'] as bool? ?? true,
    updatedAt: parseTimestamp(map['updated_at']),
  );
}
