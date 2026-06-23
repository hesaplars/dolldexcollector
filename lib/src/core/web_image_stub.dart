import 'package:flutter/material.dart';

Widget buildWebImage({
  required String imageUrl,
  required String label,
  BoxFit? fit,
}) {
  return Image.network(
    imageUrl,
    width: double.infinity,
    fit: fit ?? BoxFit.cover,
    errorBuilder: (context, error, stackTrace) =>
        _buildErrorPlaceholder(context, label),
    loadingBuilder: (context, child, loadingProgress) {
      if (loadingProgress == null) return child;
      return const Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    },
  );
}

Widget _buildErrorPlaceholder(BuildContext context, String label) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    width: double.infinity,
    color: Theme.of(context).colorScheme.surface,
    alignment: Alignment.center,
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.image_not_supported_outlined,
          color: Theme.of(context).colorScheme.primary,
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Outfit',
            color: isDark ? Colors.white24 : Colors.black26,
            fontSize: 11,
          ),
        ),
      ],
    ),
  );
}
