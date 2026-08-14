/// Derives a URL-safe slug matching the catalog `^[a-z0-9]+(?:-[a-z0-9]+)*$`
/// check constraint. Shared by the admin catalog forms.
String slugify(String value) => value
    .toLowerCase()
    .trim()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');
