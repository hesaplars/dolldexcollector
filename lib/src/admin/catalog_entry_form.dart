import 'package:flutter/material.dart';

import '../catalog/catalog_models.dart';
import '../core/app_language.dart';
import '../core/image_url_validator.dart';

class CatalogEntryDraft {
  const CatalogEntryDraft({
    required this.id,
    required this.name,
    required this.type,
    required this.subtitle,
    required this.imageUrl,
    required this.year,
    required this.tags,
    required this.description,
  });

  final String? id;
  final String name;
  final CatalogItemType type;
  final String subtitle;
  final String imageUrl;
  final int? year;
  final List<String> tags;
  final String description;
}

class CatalogEntryForm extends StatefulWidget {
  const CatalogEntryForm({
    required this.onPreviewChanged,
    required this.onSubmit,
    this.editingEntry,
    super.key,
  });

  final ValueChanged<String> onPreviewChanged;
  final ValueChanged<CatalogEntryDraft> onSubmit;
  final CatalogEntry? editingEntry;

  @override
  State<CatalogEntryForm> createState() => _CatalogEntryFormState();
}

class _CatalogEntryFormState extends State<CatalogEntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _yearController = TextEditingController();
  final _tagsController = TextEditingController();
  final _descriptionController = TextEditingController();

  CatalogItemType _type = CatalogItemType.doll;

  @override
  void initState() {
    super.initState();
    _applyEditingEntry(widget.editingEntry);
  }

  @override
  void didUpdateWidget(covariant CatalogEntryForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editingEntry?.id != widget.editingEntry?.id) {
      _applyEditingEntry(widget.editingEntry);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subtitleController.dispose();
    _imageUrlController.dispose();
    _yearController.dispose();
    _tagsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  InputDecoration _buildInputDecoration(BuildContext context, String label, IconData icon) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InputDecoration(
      labelText: label,
      prefixIcon: _buildNeonIcon(context, icon, size: 20),
      alignLabelWithHint: true,
      labelStyle: const TextStyle(fontFamily: 'Outfit'),
      hintStyle: const TextStyle(fontFamily: 'Outfit'),
      errorStyle: const TextStyle(fontFamily: 'Outfit'),
      helperStyle: const TextStyle(fontFamily: 'Outfit'),
      counterStyle: const TextStyle(fontFamily: 'Outfit'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2C1F45) : const Color(0xFFE9D8FA),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFEC008C),
          width: 2.0,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.red.shade800,
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.red.shade800,
          width: 2.0,
        ),
      ),
    );
  }

  Widget _buildGotikButton({
    required BuildContext context,
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFFEC008C), Color(0xFF7B2CBF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEC008C).withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        icon: Icon(icon, size: 18, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontFamily: 'Outfit',
            fontSize: 14,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameController,
            style: const TextStyle(fontFamily: 'Outfit'),
            decoration: _buildInputDecoration(
              context,
              AppLanguageScope.languageOf(context) == AppLanguage.tr ? 'Ad' : 'Name',
              Icons.badge_outlined,
            ),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if ((value ?? '').trim().length < 2) {
                return AppLanguageScope.languageOf(context) == AppLanguage.tr
                    ? 'Ad gerekli'
                    : 'Name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CatalogItemType>(
            initialValue: _type,
            style: TextStyle(
              fontFamily: 'Outfit',
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
            decoration: _buildInputDecoration(
              context,
              AppLanguageScope.languageOf(context) == AppLanguage.tr ? 'Tür' : 'Type',
              Icons.category_outlined,
            ),
            items: CatalogItemType.values
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(
                      _typeLabel(context, type),
                      style: const TextStyle(fontFamily: 'Outfit'),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _type = value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _subtitleController,
            style: const TextStyle(fontFamily: 'Outfit'),
            decoration: _buildInputDecoration(
              context,
              AppLanguageScope.languageOf(context) == AppLanguage.tr ? 'Kısa açıklama' : 'Short description',
              Icons.short_text_rounded,
            ),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return AppLanguageScope.languageOf(context) == AppLanguage.tr
                    ? 'Kısa açıklama gerekli'
                    : 'Short description is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _imageUrlController,
            style: const TextStyle(fontFamily: 'Outfit'),
            decoration: _buildInputDecoration(
              context,
              AppLanguageScope.languageOf(context) == AppLanguage.tr ? 'Görsel URL' : 'Image URL',
              Icons.link_rounded,
            ).copyWith(
              helperText: AppLanguageScope.languageOf(context) == AppLanguage.tr
                  ? 'Birden fazla görsel için URL\'leri virgülle ayırabilirsiniz (örn: url1, url2)'
                  : 'Separate multiple image URLs with commas (e.g., url1, url2)',
              helperStyle: const TextStyle(fontSize: 11, fontFamily: 'Outfit'),
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            validator: ImageUrlValidator.validate,
            onChanged: widget.onPreviewChanged,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _yearController,
                  style: const TextStyle(fontFamily: 'Outfit'),
                  decoration: _buildInputDecoration(
                    context,
                    AppLanguageScope.languageOf(context) == AppLanguage.tr ? 'Yıl' : 'Year',
                    Icons.calendar_today_outlined,
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final trimmed = (value ?? '').trim();
                    if (trimmed.isEmpty) {
                      return null;
                    }

                    final year = int.tryParse(trimmed);
                    if (year == null || year < 1900 || year > 2100) {
                      return AppLanguageScope.languageOf(context) == AppLanguage.tr
                          ? 'Geçersiz yıl'
                          : 'Invalid year';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _tagsController,
                  style: const TextStyle(fontFamily: 'Outfit'),
                  decoration: _buildInputDecoration(
                    context,
                    AppLanguageScope.languageOf(context) == AppLanguage.tr ? 'Etiketler' : 'Tags',
                    Icons.sell_outlined,
                  ),
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            style: const TextStyle(fontFamily: 'Outfit'),
            decoration: _buildInputDecoration(
              context,
              AppLanguageScope.languageOf(context) == AppLanguage.tr ? 'Wiki notları' : 'Wiki notes',
              Icons.notes_rounded,
            ),
            minLines: 3,
            maxLines: 6,
          ),
          const SizedBox(height: 16),
          _buildGotikButton(
            context: context,
            onPressed: _submit,
            icon: Icons.save_outlined,
            label: _submitLabel(context),
          ),
        ],
      ),
    );
  }

  Widget _buildNeonIcon(BuildContext context, IconData icon, {double size = 24}) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return const LinearGradient(
          colors: [
            Color(0xFFEC008C),
            Color(0xFF00FFCC),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds);
      },
      child: Icon(
        icon,
        color: Colors.white,
        size: size,
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);

    widget.onSubmit(
      CatalogEntryDraft(
        id: widget.editingEntry?.id,
        name: _nameController.text.trim(),
        type: _type,
        subtitle: _subtitleController.text.trim(),
        imageUrl: _imageUrlController.text.trim(),
        year: int.tryParse(_yearController.text.trim()),
        tags: tags,
        description: _descriptionController.text.trim(),
      ),
    );
    _nameController.clear();
    _subtitleController.clear();
    _imageUrlController.clear();
    _yearController.clear();
    _tagsController.clear();
    _descriptionController.clear();
    widget.onPreviewChanged('');
    setState(() {
      _type = CatalogItemType.doll;
    });
  }

  String _submitLabel(BuildContext context) {
    final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
    if (widget.editingEntry == null) {
      return tr ? 'Taslağı kaydet' : 'Save draft';
    }

    return tr ? 'Değişiklikleri kaydet' : 'Save changes';
  }

  void _applyEditingEntry(CatalogEntry? entry) {
    if (entry == null) {
      _nameController.clear();
      _subtitleController.clear();
      _imageUrlController.clear();
      _yearController.clear();
      _tagsController.clear();
      _descriptionController.clear();
      _type = CatalogItemType.doll;
      return;
    }

    _nameController.text = entry.name;
    _subtitleController.text = entry.subtitle;
    _imageUrlController.text = entry.imageUrls.join(', ');
    _yearController.text = entry.year?.toString() ?? '';
    _tagsController.text = entry.tags.join(', ');
    _descriptionController.text = entry.description;
    _type = entry.type;
  }
}

String _typeLabel(BuildContext context, CatalogItemType type) {
  final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
  return switch (type) {
    CatalogItemType.character => tr ? 'Karakter' : 'Character',
    CatalogItemType.doll => tr ? 'Bebek' : 'Doll',
    CatalogItemType.set => 'Set',
    CatalogItemType.pet => 'Pet',
    CatalogItemType.accessory => tr ? 'Aksesuar' : 'Accessory',
  };
}
