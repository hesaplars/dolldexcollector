import 'dart:html' as html;
import 'package:flutter/material.dart';

Widget buildWebImage({
  required String imageUrl,
  required String label,
  BoxFit? fit,
}) {
  return _WebImageWrapper(
    key: ValueKey(imageUrl),
    imageUrl: imageUrl,
    label: label,
    fit: fit,
  );
}

class _WebImageWrapper extends StatefulWidget {
  const _WebImageWrapper({
    required this.imageUrl,
    required this.label,
    this.fit,
    super.key,
  });

  final String imageUrl;
  final String label;
  final BoxFit? fit;

  @override
  State<_WebImageWrapper> createState() => _WebImageWrapperState();
}

class _WebImageWrapperState extends State<_WebImageWrapper> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorPlaceholder(context, widget.label);
    }
    return HtmlElementView.fromTagName(
      tagName: 'img',
      onElementCreated: (Object element) {
        final img = element as html.ImageElement;
        img.src = widget.imageUrl;
        img.alt = widget.label;
        img.style.width = '100%';
        img.style.height = '100%';
        img.style.pointerEvents = 'none';
        img.style.objectFit = widget.fit == BoxFit.contain ? 'contain' : 'cover';

        img.onError.listen((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _hasError = true;
              });
            }
          });
        });
      },
    );
  }

  Widget _buildErrorPlaceholder(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF1E152C) : const Color(0xFFFAF2FF),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: isDark ? const Color(0xFFEC008C) : const Color(0xFF8338EC),
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
}
