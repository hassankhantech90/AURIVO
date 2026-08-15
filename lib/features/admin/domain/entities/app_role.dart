/// A role definition (`public.roles`) — e.g. admin, seller, customer, support.
class AppRole {
  const AppRole({required this.id, required this.name, this.description});

  final String id;
  final String name;
  final String? description;

  factory AppRole.fromMap(Map<String, dynamic> map) {
    return AppRole(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
    );
  }
}
