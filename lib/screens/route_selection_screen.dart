import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../routes/app_router.dart';
import '../services/ride_service.dart';
import '../services/location_service.dart';

/// Screen: Plan your ride (Route Selection)
/// Allows user to specify Pickup and Destination with instant autocomplete,
/// GPS auto-detection, quick shortcuts, and smooth transitions.
class RouteSelectionScreen extends StatefulWidget {
  const RouteSelectionScreen({super.key});

  @override
  State<RouteSelectionScreen> createState() => _RouteSelectionScreenState();
}

class _RouteSelectionScreenState extends State<RouteSelectionScreen> {
  final _pickupCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _pickupFocus = FocusNode();
  final _destFocus = FocusNode();
  final _rideService = RideService();

  bool _isFetchingLocation = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;
  double _swapAngle = 0.0;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    if (state.pickupAddress.isNotEmpty) {
      _pickupCtrl.text = state.pickupAddress;
    } else if (state.currentAddress.isNotEmpty) {
      _pickupCtrl.text = state.currentAddress;
      state.setPickup(state.currentAddress, state.currentLat, state.currentLng);
    } else {
      _autoFetchLocation();
    }

    if (state.destinationAddress.isNotEmpty) {
      _destCtrl.text = state.destinationAddress;
    }

    // Auto-focus destination field smoothly
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted && _destCtrl.text.isEmpty) {
        FocusScope.of(context).requestFocus(_destFocus);
      }
    });
  }

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    _pickupFocus.dispose();
    _destFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _autoFetchLocation() async {
    setState(() {
      _isFetchingLocation = true;
      _pickupCtrl.text = 'Getting current location…';
    });

    final hasPermission = await LocationService.hasPermission();
    if (!hasPermission) {
      final granted = await LocationService.requestPermission();
      if (!granted) {
        if (mounted) {
          setState(() {
            _isFetchingLocation = false;
            _pickupCtrl.text = '';
          });
        }
        return;
      }
    }

    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;

    if (pos != null) {
      final addr = await LocationService.getAddressFromLatLng(pos.latitude, pos.longitude);
      if (mounted) {
        final label = addr.isNotEmpty ? addr : 'Current Location';
        setState(() {
          _pickupCtrl.text = label;
          _isFetchingLocation = false;
        });
        context.read<AppState>().updateCurrentLocation(pos.latitude, pos.longitude, label);
        context.read<AppState>().setPickup(label, pos.latitude, pos.longitude);
      }
    } else {
      if (mounted) {
        setState(() {
          _pickupCtrl.text = '';
          _isFetchingLocation = false;
        });
      }
    }
  }

  void _onTextChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = []);
      }
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      final state = context.read<AppState>();
      final results = await _rideService.searchLocations(
        query,
        lat: state.currentLat != 0 ? state.currentLat : null,
        lng: state.currentLng != 0 ? state.currentLng : null,
      );
      if (mounted) {
        setState(() {
          _suggestions = results ?? [];
          _isSearching = false;
        });
      }
    });
  }

  void _selectSuggestion(Map<String, dynamic> loc) {
    HapticFeedback.selectionClick();
    final state = context.read<AppState>();
    final name = loc['name'] as String? ?? '';
    final address = loc['address'] as String? ?? '';
    final fullLabel = address.isNotEmpty ? '$name, $address' : name;
    final lat = (loc['lat'] as num).toDouble();
    final lng = (loc['lng'] as num).toDouble();

    if (_pickupFocus.hasFocus) {
      _pickupCtrl.text = name;
      state.setPickup(fullLabel, lat, lng);
      setState(() => _suggestions = []);
      FocusScope.of(context).requestFocus(_destFocus);
    } else {
      _destCtrl.text = name;
      state.setDestination(fullLabel, lat, lng);
      setState(() => _suggestions = []);
      FocusScope.of(context).unfocus();

      // If pickup is already set, navigate straight to fare preview
      if (_pickupCtrl.text.isNotEmpty && _pickupCtrl.text != 'Getting current location…') {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) {
            Navigator.pushNamed(context, AppRouter.farePreview);
          }
        });
      }
    }
  }

  void _swapAddresses() {
    HapticFeedback.lightImpact();
    setState(() {
      _swapAngle += 180.0;
      final tmp = _pickupCtrl.text;
      _pickupCtrl.text = _destCtrl.text;
      _destCtrl.text = tmp;
    });
    context.read<AppState>().swapPickupAndDestination();
  }

  bool get _canProceed =>
      _pickupCtrl.text.isNotEmpty &&
      _pickupCtrl.text != 'Getting current location…' &&
      _destCtrl.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pushNamedAndRemoveUntil(context, AppRouter.home, (route) => false);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: AppColors.white,
        body: Column(
          children: [
            // ── Header & Input Section ──────────────────────────────
            Container(
              color: AppColors.white,
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top App Bar Row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 6, 16, 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pushNamedAndRemoveUntil(
                              context,
                              AppRouter.home,
                              (route) => false,
                            ),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                            color: AppColors.textDark,
                          ),
                          Text(
                            'Plan your ride',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Unified Address Card
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FA),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E9EB)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Visual Indicator Dots & Line
                            Padding(
                              padding: const EdgeInsets.only(left: 14, right: 4),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Container(
                                    width: 2,
                                    height: 28,
                                    color: const Color(0xFFD0D7DE),
                                  ),
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: AppColors.error,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Input fields column
                            Expanded(
                              child: Column(
                                children: [
                                  // Pickup Input
                                  _RouteInputField(
                                    controller: _pickupCtrl,
                                    focusNode: _pickupFocus,
                                    hintText: 'Pickup location',
                                    readOnly: _isFetchingLocation,
                                    onChanged: _onTextChanged,
                                    onClear: () {
                                      _pickupCtrl.clear();
                                      setState(() => _suggestions = []);
                                    },
                                    trailing: _isFetchingLocation
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.primary,
                                            ),
                                          )
                                        : GestureDetector(
                                            onTap: _autoFetchLocation,
                                            child: const Icon(
                                              Icons.my_location_rounded,
                                              size: 18,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                  ),

                                  const Divider(height: 1, color: Color(0xFFE5E9EB)),

                                  // Destination Input
                                  _RouteInputField(
                                    controller: _destCtrl,
                                    focusNode: _destFocus,
                                    hintText: 'Where to?',
                                    onChanged: _onTextChanged,
                                    onClear: () {
                                      _destCtrl.clear();
                                      setState(() => _suggestions = []);
                                    },
                                  ),
                                ],
                              ),
                            ),

                            // Swap Route Button
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: GestureDetector(
                                onTap: _swapAddresses,
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFE0E5E8)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween<double>(
                                      begin: 0,
                                      end: _swapAngle * (3.141592653589793 / 180.0),
                                    ),
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOutCubic,
                                    builder: (context, value, child) {
                                      return Transform.rotate(
                                        angle: value,
                                        child: child,
                                      );
                                    },
                                    child: const Icon(
                                      Icons.swap_vert_rounded,
                                      size: 18,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: Color(0xFFEEEEEE)),

            // ── Suggestions & Shortcuts Section ─────────────────────
            Expanded(
              child: _isSearching
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2.5,
                      ),
                    )
                  : _suggestions.isNotEmpty
                      ? ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _suggestions.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1, color: Color(0xFFF0F2F5)),
                          itemBuilder: (_, i) {
                            final item = _suggestions[i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              leading: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F4F7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.location_on_outlined,
                                  color: AppColors.textMedium,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                item['name'] ?? '',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: (item['address'] ?? '').isNotEmpty
                                  ? Text(
                                      item['address'],
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.textMedium,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              onTap: () => _selectSuggestion(item),
                            );
                          },
                        )
                      : _QuickShortcutsView(
                          onUseCurrentLocation: _autoFetchLocation,
                          onSelectPopular: (name) {
                            _destCtrl.text = name;
                            _onTextChanged(name);
                          },
                        ),
            ),

            // ── Bottom Action Button ────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: _canProceed
                  ? SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: FilledButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.pushNamed(context, AppRouter.farePreview);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.white,
                            minimumSize: const Size.fromHeight(54),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(PhosphorIconsRegular.carProfile, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'See Prices & Book',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact input field widget for pickup/drop
class _RouteInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final Widget? trailing;

  const _RouteInputField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    this.readOnly = false,
    this.onChanged,
    this.onClear,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              readOnly: readOnly,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: GoogleFonts.inter(
                  color: const Color(0xFF9AA5B1),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
          ),
          if (controller.text.isNotEmpty && onClear != null)
            GestureDetector(
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF9AA5B1)),
              ),
            ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Clean empty-state view displaying quick shortcuts when user hasn't typed yet
class _QuickShortcutsView extends StatelessWidget {
  final VoidCallback onUseCurrentLocation;
  final ValueChanged<String> onSelectPopular;

  const _QuickShortcutsView({
    required this.onUseCurrentLocation,
    required this.onSelectPopular,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Use Current Location Shortcut
        InkWell(
          onTap: onUseCurrentLocation,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.my_location_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Use current location',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      'Tap to detect GPS position',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const Divider(height: 20, color: Color(0xFFF0F2F5)),

        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            'Quick Suggestions',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8292A2),
              letterSpacing: 0.2,
            ),
          ),
        ),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _QuickChip(label: 'Railway Station', icon: Icons.train_outlined, onTap: () => onSelectPopular('Railway Station')),
            _QuickChip(label: 'Airport', icon: Icons.flight_outlined, onTap: () => onSelectPopular('Airport')),
            _QuickChip(label: 'City Center / Mall', icon: Icons.storefront_outlined, onTap: () => onSelectPopular('City Center Mall')),
            _QuickChip(label: 'Bus Stand', icon: Icons.directions_bus_outlined, onTap: () => onSelectPopular('Bus Terminal')),
          ],
        ),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppColors.primary),
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textDark,
        ),
      ),
      backgroundColor: const Color(0xFFF7F9FA),
      side: const BorderSide(color: Color(0xFFE5E9EB)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: onTap,
    );
  }
}
