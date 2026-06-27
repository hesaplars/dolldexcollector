import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../core/web_image_helper.dart';

import '../../main.dart';
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
    this.parentId,
    this.series,
  });

  final String? id;
  final String name;
  final CatalogItemType type;
  final String subtitle;
  final String imageUrl;
  final int? year;
  final List<String> tags;
  final String description;
  final String? parentId;
  final String? series;
}

class CatalogEntryForm extends StatefulWidget {
  const CatalogEntryForm({
    required this.onSubmit,
    this.editingEntry,
    super.key,
  });

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
  final _seriesController = TextEditingController();

  CatalogItemType _type = CatalogItemType.doll;
  int _previewPageIndex = 0;
  String? _parentId;

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
    _seriesController.dispose();
    super.dispose();
  }

  InputDecoration _buildInputDecoration(
      BuildContext context, String label, IconData icon) {
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
          color: Theme.of(context).dividerColor,
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
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
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
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
              AppLanguageScope.languageOf(context) == AppLanguage.tr
                  ? 'Ad'
                  : 'Name',
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
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
              fontSize: 14,
            ),
            decoration: _buildInputDecoration(
              context,
              AppLanguageScope.languageOf(context) == AppLanguage.tr
                  ? 'Tür'
                  : 'Type',
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
          Builder(
            key: ValueKey(widget.editingEntry?.id),
            builder: (context) {
              final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;

              // Suggestion pool:
              final existingSeries = catalogEntriesNotifier.value
                  .map((e) => e.series)
                  .whereType<String>()
                  .where((s) => s.isNotEmpty)
                  .toSet()
                  .toList();

              // English-Turkish Monster High series map:
              final Map<String, String> monsterHighSeriesMap = {
                // Generation 1 (G1)
                'core / signature': 'Temel / İmza (Core / Signature)',
                'schools out': 'Okul Çıkışı (School\'s Out)',
                'gloom beach': 'Hüzün Plajı (Gloom Beach)',
                'dawn of the dance': 'Dansın Şafağı (Dawn of the Dance)',
                'dead tired': 'Pijama Partisi (Dead Tired)',
                'classroom': 'Sınıf (Classroom)',
                'skull shores': 'Kafatası Sahili (Skull Shores)',
                'sweet 1600': 'Tatlı 1600 (Sweet 1600)',
                'roller maze': 'Paten Labirenti (Roller Maze)',
                'dot dead gorgeous': 'Puantiyeli Şıklık (Dot Dead Gorgeous)',
                'scarily ever after': 'Masal Canavarları (Scarily Ever After)',
                'ghouls rule': 'Acayip Kuralları (Ghouls Rule)',
                'ghouls alive!': 'Acayipler Canlanıyor! (Ghouls Alive!)',
                'picture day': 'Albüm Günü (Picture Day)',
                'dance class': 'Dans Sınıfı (Dance Class)',
                'scaris: city of frights':
                    'Korku Şehri Scaris (Scaris: City of Frights)',
                'music festival': 'Müzik Festivali (Music Festival)',
                '13 wishes': '13 Dilek (13 Wishes)',
                'ghouls night out': 'Acayiplerin Gecesi (Ghouls\' Night Out)',
                'power ghouls': 'Güçlü Acayipler (Power Ghouls)',
                'sweet screams': 'Tatlı Çığlıklar (Sweet Screams)',
                'frights, camera, action!':
                    'Dehşet, Kamera, Motor! (Frights, Camera, Action!)',
                'swim class': 'Yüzme Sınıfı (Swim Class)',
                'coffin bean': 'Tabut Cafe (Coffin Bean)',
                'art class': 'Resim Sınıfı (Art Class)',
                'ghoul spirit': 'Okul Ruhu (Ghoul Spirit)',
                'scaremester': 'Yeni Dönem (Scaremester)',
                'creepateria': 'Ucube Kafeterya (Creepateria)',
                'zombie shake': 'Zombi Dansı (Zombie Shake)',
                'freaky fusion': 'Acayip Kaynaşma (Freaky Fusion)',
                'freaky field trip': 'Acayip Okul Gezisi (Freaky Field Trip)',
                'ghoul sports': 'Acayip Sporlar (Ghoul Sports)',
                'inner monster': 'İçimdeki Canavar (Inner Monster)',
                'student disembody council':
                    'Okul Öğrenci Temsilcileri (Student Disembody Council)',
                'haunted': 'Hayaletli (Haunted)',
                'gloom and bloom': 'Karanlık Çiçek Açımı (Gloom and Bloom)',
                'monster exchange':
                    'Canavar Değişim Programı (Monster Exchange)',
                'geek shriek': 'İnek Acayipler (Geek Shriek)',
                'freak du chic': 'Şık Ucubeler (Freak du Chic)',
                'brand boo students': 'Yepyeni Acayipler (Brand Boo Students)',
                'welcome to monster high':
                    'Monster High\'a Hoş Geldiniz (Welcome to Monster High)',
                'monsters in training':
                    'Eğitimdeki Canavarlar (Monsters in Training)',
                'shriekwrecked': 'Korsan Macerası (Shriekwrecked)',
                'electrified': 'Neon Şıklık (Electrified)',

                // Generation 2 (G2)
                'how do you boo?': 'Nasıl Ürkütürsün? (How Do You Boo?)',
                'ghouls beast pet':
                    'Acayip Evcil Hayvanları (Ghoul\'s Beast Pet)',
                'garden ghouls': 'Bahçe Acayipleri (Garden Ghouls)',
                'monster family': 'Canavar Ailesi (Monster Family)',
                'party ghouls': 'Parti Acayipleri (Party Ghouls)',
                'ballerina ghouls': 'Balerin Acayipleri (Ballerina Ghouls)',
                'swimsuit': 'Mayo Serisi (Swimsuit)',
                'transforming ghouls':
                    'Dönüşen Acayipler (Transforming Ghouls)',
                'lots of looks': 'Farklı Görünümler (Lots of Looks)',
                'one team, one scream':
                    'Tek Takım, Tek Çığlık (One Team, One Scream)',
                'teen hangout': 'Gençlerin Mekanı (Teen Hangout)',
                'comic book': 'Çizgi Roman (Comic Book)',

                // Generation 3 (G3)
                'creepover party': 'Pijama Partisi (Creepover Party)',
                'skulltimate secrets': 'Gizemli Dolaplar (Skulltimate Secrets)',
                'monster ball': 'Canavar Balosu (Monster Ball)',
                'neon frights': 'Neon Dehşetler (Neon Frights)',
                'fearidescent': 'Işıltılı Korku (Fearidescent)',
                'monster fest': 'Canavar Festivali (Monster Fest)',
                'fearbook': 'Yıllık Kulübü (Fearbook)',
                'core refresh': 'Yeni İmza (Core Refresh)',
                'hissfits': 'Grup Serisi (Hissfits)',
              };

              final allOptions = <String>{};
              allOptions.addAll(existingSeries);
              allOptions.addAll(monsterHighSeriesMap.values);

              return Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  final text = textEditingValue.text.toLowerCase();
                  return allOptions.where((option) {
                    final optLower = option.toLowerCase();
                    if (optLower.contains(text)) {
                      return true;
                    }
                    for (final entry in monsterHighSeriesMap.entries) {
                      if (entry.key.contains(text) && entry.value == option) {
                        return true;
                      }
                    }
                    return false;
                  });
                },
                onSelected: (String selection) {
                  _seriesController.text = selection;
                },
                fieldViewBuilder: (context, textEditingController, focusNode,
                    onFieldSubmitted) {
                  if (textEditingController.text != _seriesController.text &&
                      _seriesController.text.isNotEmpty &&
                      textEditingController.text.isEmpty) {
                    textEditingController.text = _seriesController.text;
                  }
                  textEditingController.addListener(() {
                    _seriesController.text = textEditingController.text;
                  });
                  return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    onFieldSubmitted: (value) => onFieldSubmitted(),
                    decoration: _buildInputDecoration(
                      context,
                      tr
                          ? 'Konsept / Seri (Örn: Pijama Partisi)'
                          : 'Concept / Series (e.g. Dead Tired)',
                      Icons.category_rounded,
                    ),
                    style: const TextStyle(fontFamily: 'Outfit'),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  final theme = Theme.of(context);
                  final isDark = theme.brightness == Brightness.dark;
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      borderRadius: BorderRadius.circular(12),
                      color: theme.cardTheme.color ??
                          (isDark ? const Color(0xFF150A21) : Colors.white),
                      child: Container(
                        width: 320,
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final String option = options.elementAt(index);
                            return InkWell(
                              onTap: () => onSelected(option),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 12.0),
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
              final parentCandidates = catalogEntriesNotifier.value
                  .where((e) =>
                      e.type == CatalogItemType.doll ||
                      e.type == CatalogItemType.set)
                  .toList();

              return DropdownButtonFormField<String?>(
                value: _parentId,
                dropdownColor: Theme.of(context).cardTheme.color ??
                    (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF150A21)
                        : Colors.white),
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                  fontSize: 14,
                ),
                decoration: _buildInputDecoration(
                  context,
                  tr
                      ? 'Ana Bebek / Set (İsteğe Bağlı)'
                      : 'Parent Doll / Set (Optional)',
                  Icons.link_rounded,
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      tr ? 'Yok / Ana Öge' : 'None / Main Item',
                      style: const TextStyle(fontFamily: 'Outfit'),
                    ),
                  ),
                  ...parentCandidates.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(
                        '${c.name} (${c.year ?? ''})',
                        style: const TextStyle(fontFamily: 'Outfit'),
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _parentId = value);
                },
              );
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _subtitleController,
            style: const TextStyle(fontFamily: 'Outfit'),
            decoration: _buildInputDecoration(
              context,
              AppLanguageScope.languageOf(context) == AppLanguage.tr
                  ? 'Kısa açıklama'
                  : 'Short description',
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
              AppLanguageScope.languageOf(context) == AppLanguage.tr
                  ? 'Görsel URL'
                  : 'Image URL',
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
            onChanged: (value) {
              final urls = value
                  .split(',')
                  .map((u) => u.trim())
                  .where((u) => u.isNotEmpty)
                  .toList();
              setState(() {
                if (_previewPageIndex >= urls.length) {
                  _previewPageIndex = 0;
                }
              });
            },
          ),
          Builder(
            builder: (context) {
              final val = _imageUrlController.text.trim();
              final urls = val
                  .split(',')
                  .map((u) => u.trim())
                  .where((u) => u.isNotEmpty)
                  .toList();
              return _buildImagePreview(context, urls);
            },
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
                    AppLanguageScope.languageOf(context) == AppLanguage.tr
                        ? 'Yıl'
                        : 'Year',
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
                      return AppLanguageScope.languageOf(context) ==
                              AppLanguage.tr
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
                    AppLanguageScope.languageOf(context) == AppLanguage.tr
                        ? 'Etiketler'
                        : 'Tags',
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
              AppLanguageScope.languageOf(context) == AppLanguage.tr
                  ? 'Wiki notları'
                  : 'Wiki notes',
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

  Widget _buildNeonIcon(BuildContext context, IconData icon,
      {double size = 24}) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
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
        parentId: _parentId,
        series: _seriesController.text.trim().isEmpty
            ? null
            : _seriesController.text.trim(),
      ),
    );
    _nameController.clear();
    _subtitleController.clear();
    _imageUrlController.clear();
    _yearController.clear();
    _tagsController.clear();
    _descriptionController.clear();
    _seriesController.clear();
    _previewPageIndex = 0;
    setState(() {
      _type = CatalogItemType.doll;
      _parentId = null;
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
    _previewPageIndex = 0;
    if (entry == null) {
      _nameController.clear();
      _subtitleController.clear();
      _imageUrlController.clear();
      _yearController.clear();
      _tagsController.clear();
      _descriptionController.clear();
      _seriesController.clear();
      _type = CatalogItemType.doll;
      _parentId = null;
      return;
    }

    _nameController.text = entry.name;
    _subtitleController.text = entry.subtitle;
    _imageUrlController.text = entry.imageUrls.join(', ');
    _yearController.text = entry.year?.toString() ?? '';
    _tagsController.text = entry.tags.join(', ');
    _descriptionController.text = entry.description;
    _seriesController.text = entry.series ?? '';
    _type = entry.type;
    _parentId = entry.parentId;
  }

  Widget _buildImagePreview(BuildContext context, List<String> urls) {
    if (urls.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Center(
        child: Container(
          width: 150,
          height: 150 / 0.58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                PageView.builder(
                  itemCount: urls.length,
                  onPageChanged: (index) {
                    setState(() {
                      _previewPageIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final url = urls[index];
                    return kIsWeb
                        ? getWebImage(
                            imageUrl: url,
                            label: 'Preview',
                            fit: BoxFit.cover,
                          )
                        : Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade900,
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white24,
                                  size: 40,
                                ),
                              );
                            },
                          );
                  },
                ),
                if (urls.length > 1) ...[
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(urls.length, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _previewPageIndex == index ? 8 : 5,
                          height: _previewPageIndex == index ? 8 : 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _previewPageIndex == index
                                ? Theme.of(context).colorScheme.secondary
                                : Colors.white.withValues(alpha: 0.5),
                          ),
                        );
                      }),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_previewPageIndex + 1}/${urls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
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
