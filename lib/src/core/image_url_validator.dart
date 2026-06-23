class ImageUrlValidator {
  const ImageUrlValidator._();

  static bool isAllowed(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      return false;
    }
    return true;
  }

  static String? validate(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Görsel URL gerekli';
    }

    final urls =
        trimmed.split(',').map((u) => u.trim()).where((u) => u.isNotEmpty);
    if (urls.isEmpty) {
      return 'Görsel URL gerekli';
    }

    for (final url in urls) {
      if (!isAllowed(url)) {
        return 'Geçerli bir görsel URL\'si girin (örn: https://...)';
      }
    }

    return null;
  }
}
