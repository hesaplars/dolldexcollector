import 'package:flutter/material.dart';

import '../catalog/catalog_models.dart';
import '../core/app_language.dart';
import '../widgets/doll_widgets.dart';

class CollectionActionSheet extends StatefulWidget {
  const CollectionActionSheet({
    required this.item,
    required this.onSave,
    this.initialEntry,
    this.onDelete,
    super.key,
  });

  final CatalogEntry item;
  final Future<bool> Function(CollectionEntryDraft) onSave;
  final CollectionEntry? initialEntry;
  final Future<bool> Function()? onDelete;

  @override
  State<CollectionActionSheet> createState() => _CollectionActionSheetState();
}

class _CollectionActionSheetState extends State<CollectionActionSheet> {
  final _notesController = TextEditingController();
  CollectionStatus _status = CollectionStatus.owned;
  CollectionCondition _condition = CollectionCondition.complete;
  int _quantity = 1;
  bool _isPublic = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialEntry != null) {
      _notesController.text = widget.initialEntry!.notes;
      _status = widget.initialEntry!.status;
      _condition = widget.initialEntry!.condition;
      _quantity = widget.initialEntry!.quantity;
      _isPublic = widget.initialEntry!.isPublic;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Widget _buildStatusSelectionCard(CollectionStatus status, IconData icon, String label) {
    final isSelected = _status == status;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final panelColor = isDark ? DollDexTheme.darkPanel : const Color(0xFFFFF4DC);
    final lineColor = isDark ? DollDexTheme.darkLine : DollDexTheme.line;
    final textColor = isSelected ? accent : (isDark ? Colors.white70 : DollDexTheme.cocoa);

    return InkWell(
      onTap: () => setState(() => _status = status),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accent.withOpacity(0.12) : panelColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accent : lineColor,
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accent.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? accent : (isDark ? Colors.white54 : DollDexTheme.cocoa.withOpacity(0.7)),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop();
      },
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _entryName(context, widget.item),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.8,
              children: [
                _buildStatusSelectionCard(CollectionStatus.owned, Icons.check_circle_outline_rounded, t(context, 'owned')),
                _buildStatusSelectionCard(CollectionStatus.wanted, Icons.favorite_border_rounded, t(context, 'wanted')),
                _buildStatusSelectionCard(CollectionStatus.trade, Icons.swap_horiz_rounded, t(context, 'trade')),
                _buildStatusSelectionCard(CollectionStatus.selling, Icons.sell_outlined, t(context, 'selling')),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CollectionCondition>(
              initialValue: _condition,
              decoration: InputDecoration(
                labelText:
                    AppLanguageScope.languageOf(context) == AppLanguage.tr
                        ? 'Durum'
                        : 'Condition',
                prefixIcon: const Icon(Icons.fact_check_outlined),
              ),
              items: CollectionCondition.values
                  .map(
                    (condition) => DropdownMenuItem(
                      value: condition,
                      child: Text(_conditionLabel(context, condition)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _condition = value);
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.outlined(
                  tooltip: 'Decrease',
                  onPressed: _quantity > 1
                      ? () => setState(() => _quantity -= 1)
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    AppLanguageScope.languageOf(context) == AppLanguage.tr
                        ? 'Adet $_quantity'
                        : 'Qty $_quantity',
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Increase',
                  onPressed: () => setState(() => _quantity += 1),
                  icon: const Icon(Icons.add_rounded),
                ),
                const Spacer(),
                Text(
                  AppLanguageScope.languageOf(context) == AppLanguage.tr
                      ? 'Herkese açık'
                      : 'Public',
                ),
                Switch(
                  value: _isPublic,
                  onChanged: (value) => setState(() => _isPublic = value),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText:
                    AppLanguageScope.languageOf(context) == AppLanguage.tr
                        ? 'Notlar'
                        : 'Notes',
                alignLabelWithHint: true,
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.initialEntry != null && widget.onDelete != null) ...[
                  Expanded(
                    flex: 1,
                    child: InkWell(
                      onTap: () async {
                        final success = await widget.onDelete!();
                        if (success && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: Colors.redAccent, width: 1.5),
                          color: Colors.redAccent.withValues(alpha: 0.08),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.delete_outline_rounded,
                                color: Colors.redAccent, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              AppLanguageScope.languageOf(context) ==
                                      AppLanguage.tr
                                  ? 'Sil'
                                  : 'Delete',
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () async {
                      final success = await widget.onSave(
                        CollectionEntryDraft(
                          itemId: widget.item.id,
                          status: _status,
                          condition: _condition,
                          quantity: _quantity,
                          isPublic: _isPublic,
                          notes: _notesController.text.trim(),
                        ),
                      );
                      if (success && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [DollDexTheme.teal, Color(0xFFFF7A1F)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: DollDexTheme.teal.withValues(alpha: 0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.save_outlined,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            AppLanguageScope.languageOf(context) ==
                                    AppLanguage.tr
                                ? 'Koleksiyona kaydet'
                                : 'Save to collection',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),);
  }
}

class CollectionEntryDraft {
  const CollectionEntryDraft({
    required this.itemId,
    required this.status,
    required this.condition,
    required this.quantity,
    required this.isPublic,
    required this.notes,
  });

  final String itemId;
  final CollectionStatus status;
  final CollectionCondition condition;
  final int quantity;
  final bool isPublic;
  final String notes;
}

String _conditionLabel(BuildContext context, CollectionCondition condition) {
  final tr = AppLanguageScope.languageOf(context) == AppLanguage.tr;
  return switch (condition) {
    CollectionCondition.boxed => tr ? 'Kutulu' : 'Boxed',
    CollectionCondition.unboxed => tr ? 'Kutusuz' : 'Unboxed',
    CollectionCondition.complete => tr ? 'Tam' : 'Complete',
    CollectionCondition.incomplete => tr ? 'Eksik' : 'Incomplete',
    CollectionCondition.damaged => tr ? 'Hasarlı' : 'Damaged',
  };
}

String _entryName(BuildContext context, CatalogEntry item) {
  return switch (item.id) {
    'template-character' => t(context, 'templateCharacterName'),
    'template-doll' => t(context, 'templateDollName'),
    'template-pet' => t(context, 'templatePetName'),
    'template-accessory' => t(context, 'templateAccessoryName'),
    _ => item.name,
  };
}
