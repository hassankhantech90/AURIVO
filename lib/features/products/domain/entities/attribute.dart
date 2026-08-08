import '../../../../core/utils/db_parsing.dart';

/// Normalized product attribute definition (`public.attributes`), e.g. material,
/// purity, size, colour.
class Attribute {
  const Attribute({
    required this.id,
    required this.name,
    required this.slug,
    this.dataType = 'text',
    this.unit,
    this.isFilterable = true,
  });

  final String id;
  final String name;
  final String slug;
  final String dataType;
  final String? unit;
  final bool isFilterable;

  factory Attribute.fromMap(Map<String, dynamic> map) {
    return Attribute(
      id: map['id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      dataType: map['data_type'] as String? ?? 'text',
      unit: map['unit'] as String?,
      isFilterable: map['is_filterable'] as bool? ?? true,
    );
  }
}

/// Reusable value for a normalized [Attribute] (`public.attribute_values`).
class AttributeValue {
  const AttributeValue({
    required this.id,
    required this.attributeId,
    required this.value,
    this.normalizedValue,
    this.sortOrder = 0,
  });

  final String id;
  final String attributeId;
  final String value;
  final String? normalizedValue;
  final int sortOrder;

  factory AttributeValue.fromMap(Map<String, dynamic> map) {
    return AttributeValue(
      id: map['id'] as String,
      attributeId: map['attribute_id'] as String,
      value: map['value'] as String,
      normalizedValue: map['normalized_value'] as String?,
      sortOrder: parseInt(map['sort_order']),
    );
  }
}
