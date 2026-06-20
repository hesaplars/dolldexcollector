import 'package:flutter/material.dart';
import 'web_image_stub.dart' if (dart.library.html) 'web_image_web.dart';

Widget getWebImage({
  required String imageUrl,
  required String label,
  BoxFit? fit,
}) {
  return buildWebImage(imageUrl: imageUrl, label: label, fit: fit);
}
