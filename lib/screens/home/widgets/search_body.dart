import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import 'search_hint.dart';

class SearchBody extends StatelessWidget {
  final TextEditingController pickupCtrl;
  final TextEditingController destCtrl;
  final FocusNode pickupFocus;
  final FocusNode destFocus;
  final List<Map<String, dynamic>> suggestions;
  final bool isSearching;
  final bool canBook;
  final ValueChanged<String> onType;
  final ValueChanged<Map<String, dynamic>> onPickSuggestion;
  final VoidCallback onBack;
  final VoidCallback onBook;

  const SearchBody({
    super.key,
    required this.pickupCtrl,
    required this.destCtrl,
    required this.pickupFocus,
    required this.destFocus,
    required this.suggestions,
    required this.isSearching,
    required this.canBook,
    required this.onType,
    required this.onPickSuggestion,
    required this.onBack,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Compact header ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 16, 10),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.textDark, size: 22),
              ),
              const Text(
                'Plan your ride',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),

        // ── Unified route card ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 12,
                    offset: Offset(0, 3)),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Timeline
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.white,
                          border: Border.all(
                              color: AppColors.primary, width: 2.5),
                        ),
                      ),
                      Container(
                        width: 1.5,
                        height: 22,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: AppColors.divider,
                      ),
                      Container(
                        width: 11,
                        height: 11,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),

                // Fields
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: pickupCtrl,
                        focusNode: pickupFocus,
                        onChanged: onType,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Pickup location',
                          hintStyle: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.only(top: 16, bottom: 12, left: 12, right: 12),
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.divider),
                      TextField(
                        controller: destCtrl,
                        focusNode: destFocus,
                        onChanged: onType,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Where are you going?',
                          hintStyle: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: const EdgeInsets.only(top: 12, bottom: 16, left: 12, right: 12),
                          suffixIcon: destCtrl.text.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    destCtrl.clear();
                                    onType('');
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(Icons.close_rounded,
                                        size: 18,
                                        color: AppColors.textMedium),
                                  ),
                                )
                              : null,
                          suffixIconConstraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                      ),
                    ],
                  ),
                ),

                // Swap button
                GestureDetector(
                  onTap: () {
                    final tmp = pickupCtrl.text;
                    pickupCtrl.text = destCtrl.text;
                    destCtrl.text = tmp;
                    onType(destCtrl.text);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppColors.backgroundGrey,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.swap_vert_rounded,
                          size: 18, color: AppColors.textMedium),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.divider),

        // ── Suggestions / recent hint ──────────────────────────────────
        Expanded(
          child: isSearching
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2.5),
                )
              : suggestions.isEmpty && !canBook
                  ? const SearchHint()
                  : suggestions.isEmpty
                      ? const SizedBox.shrink()
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: suggestions.length,
                          itemBuilder: (_, i) {
                            final item = suggestions[i];
                            return InkWell(
                              onTap: () => onPickSuggestion(item),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.location_on_rounded,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['name'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textDark,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if ((item['address'] ?? '').isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              item['address'],
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textMedium),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.north_west_rounded,
                                        size: 14, color: AppColors.textLight),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),

        // ── Book button ────────────────────────────────────────────────
        if (canBook)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: FilledButton.icon(
              onPressed: onBook,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.local_taxi_rounded, size: 20),
              label: const Text(
                'Find Cabs',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}
