import 'package:flutter/material.dart';

import '../catalog/catalog_models.dart';
import '../core/app_language.dart';

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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
            SegmentedButton<CollectionStatus>(
              segments: [
                ButtonSegment(
                  value: CollectionStatus.owned,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(t(context, 'owned')),
                ),
                ButtonSegment(
                  value: CollectionStatus.wanted,
                  icon: const Icon(Icons.favorite_border_rounded),
                  label: Text(t(context, 'wanted')),
                ),
                ButtonSegment(
                  value: CollectionStatus.trade,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: Text(t(context, 'trade')),
                ),
                ButtonSegment(
                  value: CollectionStatus.selling,
                  icon: const Icon(Icons.sell_outlined),
                  label: Text(t(context, 'selling')),
                ),
              ],
              selected: {_status},
              onSelectionChanged: (value) {
                setState(() => _status = value.first);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CollectionCondition>(
              initialValue: _condition,
              decoration: InputDecoration(
                labelText: AppLanguageScope.languageOf(context) == AppLanguage.tr
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
                labelText: AppLanguageScope.languageOf(context) == AppLanguage.tr
                    ? 'Notlar'
                    : 'Notes',
                alignLabelWithHint: true,
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 14),
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
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent, width: 1.5),
                          color: Colors.redAccent.withOpacity(0.08),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              AppLanguageScope.languageOf(context) == AppLanguage.tr
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
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEC008C), Color(0xFF8338EC)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEC008C).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.save_outlined, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            AppLanguageScope.languageOf(context) == AppLanguage.tr
                                ? 'Koleksiyona kaydet'
                                : 'Save to collection',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              letterSpacing: 0.5,
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
    );
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
