import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

Widget buildWebImage({
  required String imageUrl,
  required String label,
  BoxFit? fit,
}) {
  return _WebImageWrapper(
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
  });

  final String imageUrl;
  final String label;
  final BoxFit? fit;

  @override
  State<_WebImageWrapper> createState() => _WebImageWrapperState();
}

class _WebImageWrapperState extends State<_WebImageWrapper> {
  bool _hasError = false;
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'img-${widget.imageUrl.hashCode}-${DateTime.now().microsecondsSinceEpoch}';
    
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final img = html.ImageElement()
        ..src = widget.imageUrl
        ..alt = widget.label
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.pointerEvents = 'none'
        ..style.objectFit = widget.fit == BoxFit.contain ? 'contain' : 'cover';

      img.onError.listen((_) {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      });
      return img;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorPlaceholder(context, widget.label);
    }
    return HtmlElementView(viewType: _viewId);
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
