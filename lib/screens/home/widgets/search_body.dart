import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../providers/app_state.dart';
import '../../../theme/app_colors.dart';
import 'home_widgets.dart';

class SearchBody extends StatelessWidget {
  final TextEditingController pickupCtrl;
  final TextEditingController destCtrl;
  final FocusNode pickupFocus;
  final FocusNode destFocus;
  final List<Map<String, dynamic>> suggestions;
  final List<PlaceItem> recentPlaces;
  final bool isSearching;
  final bool canBook;
  final ValueChanged<String> onType;
  final ValueChanged<Map<String, dynamic>> onPickSuggestion;
  final void Function(PlaceItem) onPickRecent;
  final VoidCallback onBack;
  final VoidCallback onBook;

  const SearchBody({
    super.key,
    required this.pickupCtrl,
    required this.destCtrl,
    required this.pickupFocus,
    required this.destFocus,
    required this.suggestions,
    required this.recentPlaces,
    required this.isSearching,
    required this.canBook,
    required this.onType,
    required this.onPickSuggestion,
    required this.onPickRecent,
    required this.onBack,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;
    final showRecents = !isSearching && suggestions.isEmpty;

    return Column(
      children: [
        _CompactHeader(onBack: onBack),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.border,
                width:  1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF111111).withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _InputFields(
                    pickupCtrl: pickupCtrl,
                    destCtrl: destCtrl,
                    pickupFocus: pickupFocus,
                    destFocus: destFocus,
                    onType: onType,
                  ),
                ),
                AnimatedSwapButton(
                  pickupCtrl: pickupCtrl,
                  destCtrl: destCtrl,
                  onType: onType,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.divider),

        Expanded(
          child: isSearching
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2.5,
                  ),
                )
              : suggestions.isNotEmpty
                  ? ListView.builder(
                      padding: EdgeInsets.only(bottom: keyboardH + 16),
                      itemCount: suggestions.length,
                      itemBuilder: (_, i) => _SuggestionRow(
                        item: suggestions[i],
                        onTap: () => onPickSuggestion(suggestions[i]),
                      ),
                    )
                  : showRecents && recentPlaces.isNotEmpty
                      ? _RecentSection(
                          places: recentPlaces,
                          onTap: onPickRecent,
                        )
                      : const SizedBox.shrink(),
        ),

        if (canBook)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: FilledButton.icon(
              onPressed: onBook,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 20),
              label: const Text(
                'Find Rides',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }
}

class _RecentSection extends StatelessWidget {
  final List<PlaceItem> places;
  final void Function(PlaceItem) onTap;

  const _RecentSection({required this.places, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              final place = places[i];
              final isLast = i == places.length - 1;
              return _RecentPlaceRow(
                place: place,
                showDivider: !isLast,
                onTap: () => onTap(place),
              );
            },
            childCount: places.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _RecentPlaceRow extends StatelessWidget {
  final PlaceItem place;
  final VoidCallback onTap;
  final bool showDivider;

  const _RecentPlaceRow({
    required this.place,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundGrey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(place.icon, size: 18, color: AppColors.textMedium),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (place.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          place.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.north_west_rounded,
                    size: 13, color: AppColors.textLight),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 74, endIndent: 20, color: AppColors.divider),
      ],
    );
  }
}

class _CompactHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _CompactHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textDark,
              size: 22,
            ),
          ),
          const Text(
            'Plan your ride',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InputFields extends StatelessWidget {
  final TextEditingController pickupCtrl;
  final TextEditingController destCtrl;
  final FocusNode pickupFocus;
  final FocusNode destFocus;
  final ValueChanged<String> onType;

  const _InputFields({
    required this.pickupCtrl,
    required this.destCtrl,
    required this.pickupFocus,
    required this.destFocus,
    required this.onType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: pickupCtrl,
          focusNode: pickupFocus,
          onChanged: onType,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
          decoration: InputDecoration(
            hintText: 'Pickup location',
            hintStyle: const TextStyle(
              color: AppColors.textLight,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            filled: false,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 16, right: 8),
              child: Icon(Icons.circle, color: AppColors.primary, size: 8),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: pickupCtrl,
              builder: (context, value, _) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () { pickupCtrl.clear(); onType(''); },
                  child: const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.close_rounded, size: 18, color: AppColors.textMedium),
                  ),
                );
              },
            ),
            suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
        TextField(
          controller: destCtrl,
          focusNode: destFocus,
          onChanged: onType,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
          decoration: InputDecoration(
            hintText: 'Where are you going?',
            hintStyle: const TextStyle(
              color: AppColors.textLight,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            filled: false,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 16, right: 8),
              child: Icon(Icons.circle, color: AppColors.error, size: 8),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: destCtrl,
              builder: (context, value, _) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () { destCtrl.clear(); onType(''); },
                  child: const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.close_rounded, size: 18, color: AppColors.textMedium),
                  ),
                );
              },
            ),
            suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ),
      ],
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _SuggestionRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.location_on_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMedium,
                      ),
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
  }
}

class AnimatedSwapButton extends StatefulWidget {
  final TextEditingController pickupCtrl;
  final TextEditingController destCtrl;
  final ValueChanged<String> onType;

  const AnimatedSwapButton({
    super.key,
    required this.pickupCtrl,
    required this.destCtrl,
    required this.onType,
  });

  @override
  State<AnimatedSwapButton> createState() => _AnimatedSwapButtonState();
}

class _AnimatedSwapButtonState extends State<AnimatedSwapButton> {
  double _swapAngle = 0.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _swapAngle += 180.0;
          final tmp = widget.pickupCtrl.text;
          widget.pickupCtrl.text = widget.destCtrl.text;
          widget.destCtrl.text = tmp;
          widget.onType(widget.destCtrl.text);
        });
        context.read<AppState>().swapPickupAndDestination();
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
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(
                begin: 0, end: _swapAngle * (3.141592653589793 / 180.0)),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutBack,
            builder: (context, value, child) =>
                Transform.rotate(angle: value, child: child),
            child: const Icon(Icons.swap_vert_rounded,
                size: 18, color: AppColors.textMedium),
          ),
        ),
      ),
    );
  }
}
