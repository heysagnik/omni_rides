import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../routes/app_router.dart';
import '../services/ride_service.dart';
import '../services/location_service.dart';

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

  String _activeField = 'destination';
  bool _isFetchingLocation = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _pickupFocus.addListener(() {
      if (_pickupFocus.hasFocus && _activeField != 'pickup') {
        setState(() { _activeField = 'pickup'; _suggestions = []; });
      }
    });
    _destFocus.addListener(() {
      if (_destFocus.hasFocus && _activeField != 'destination') {
        setState(() { _activeField = 'destination'; _suggestions = []; });
      }
    });

    final state = context.read<AppState>();
    if (state.pickupAddress.isNotEmpty) {
      _pickupCtrl.text = state.pickupAddress;
    } else if (state.currentAddress.isNotEmpty) {
      _pickupCtrl.text = state.currentAddress;
      state.setPickup(state.currentAddress, state.currentLat, state.currentLng);
    } else {
      _autoFetchLocation();
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) FocusScope.of(context).requestFocus(_destFocus);
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
    setState(() { _isFetchingLocation = true; _pickupCtrl.text = 'Getting location…'; });
    final hasPermission = await LocationService.hasPermission();
    if (!hasPermission) {
      final granted = await LocationService.requestPermission();
      if (!granted) {
        if (mounted) setState(() { _isFetchingLocation = false; _pickupCtrl.text = ''; });
        return;
      }
    }
    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;
    if (pos != null) {
      final addr = await LocationService.getAddressFromLatLng(pos.latitude, pos.longitude);
      if (mounted) {
        final label = addr.isNotEmpty ? addr : 'Current Location';
        setState(() { _pickupCtrl.text = label; _isFetchingLocation = false; });
        context.read<AppState>().updateCurrentLocation(pos.latitude, pos.longitude, label);
      }
    } else {
      if (mounted) setState(() { _pickupCtrl.text = ''; _isFetchingLocation = false; });
    }
  }

  void _onTextChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      final state = context.read<AppState>();
      final results = await _rideService.searchLocations(
        query,
        lat: state.currentLat != 0 ? state.currentLat : null,
        lng: state.currentLng != 0 ? state.currentLng : null,
      );
      if (mounted) setState(() { _suggestions = results ?? []; _isSearching = false; });
    });
  }

  void _selectSuggestion(Map<String, dynamic> loc) {
    final state = context.read<AppState>();
    final name = loc['name'] as String? ?? '';
    final lat = (loc['lat'] as num).toDouble();
    final lng = (loc['lng'] as num).toDouble();
    if (_activeField == 'pickup') {
      _pickupCtrl.text = name;
      state.setPickup(name, lat, lng);
      setState(() => _suggestions = []);
      FocusScope.of(context).requestFocus(_destFocus);
    } else {
      _destCtrl.text = name;
      state.setDestination(name, lat, lng);
      setState(() => _suggestions = []);
      FocusScope.of(context).unfocus();
    }
  }

  bool get _canProceed =>
      _pickupCtrl.text.isNotEmpty &&
      _pickupCtrl.text != 'Getting location…' &&
      _destCtrl.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            color: AppColors.white,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back + title row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                          color: AppColors.textDark,
                        ),
                        const Text(
                          'Plan your ride',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Route input card
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Timeline indicator
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 20, 12, 20),
                            child: Column(
                              children: [
                                Container(
                                  width: 11,
                                  height: 11,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.white,
                                    border: Border.all(color: AppColors.primary, width: 2.5),
                                  ),
                                ),
                                Container(
                                  width: 2,
                                  height: 28,
                                  margin: const EdgeInsets.symmetric(vertical: 5),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [AppColors.primary, AppColors.error],
                                    ),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
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

                          // Input fields
                          Expanded(
                            child: Column(
                              children: [
                                // Pickup
                                _InputField(
                                  controller: _pickupCtrl,
                                  focusNode: _pickupFocus,
                                  hint: 'Pickup location',
                                  isActive: _activeField == 'pickup',
                                  readOnly: _isFetchingLocation,
                                  onChanged: _onTextChanged,
                                  trailing: _isFetchingLocation
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: AppColors.primary),
                                        )
                                      : GestureDetector(
                                          onTap: _autoFetchLocation,
                                          child: const Icon(Icons.my_location_rounded,
                                              size: 20, color: AppColors.primary),
                                        ),
                                ),
                                Divider(height: 1, color: AppColors.border),
                                // Destination
                                _InputField(
                                  controller: _destCtrl,
                                  focusNode: _destFocus,
                                  hint: 'Where to?',
                                  isActive: _activeField == 'destination',
                                  onChanged: _onTextChanged,
                                ),
                              ],
                            ),
                          ),

                          // Swap button
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 14, 12, 0),
                            child: GestureDetector(
                              onTap: () {
                                final tmp = _pickupCtrl.text;
                                _pickupCtrl.text = _destCtrl.text;
                                _destCtrl.text = tmp;
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.border),
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
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),

          // ── Suggestions ───────────────────────────────────────────────────
          Expanded(
            child: _isSearching
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2.5))
                : _suggestions.isEmpty
                    ? _EmptyHint(activeField: _activeField)
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: AppColors.divider),
                        itemBuilder: (_, i) {
                          final item = _suggestions[i];
                          return InkWell(
                            onTap: () => _selectSuggestion(item),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.location_on_outlined,
                                        color: AppColors.textMedium, size: 18),
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
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // ── Confirm button ────────────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _canProceed
                ? Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomPad),
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRouter.searching),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car_rounded, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Find a ride',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool isActive;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  const _InputField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.isActive,
    this.readOnly = false,
    this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      color: isActive
          ? AppColors.primary.withValues(alpha: 0.04)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              readOnly: readOnly,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                    color: AppColors.textLight, fontSize: 15),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String activeField;
  const _EmptyHint({required this.activeField});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Icon(
              activeField == 'pickup'
                  ? Icons.my_location_rounded
                  : Icons.search_rounded,
              size: 28,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            activeField == 'pickup'
                ? 'Search for a pickup point'
                : 'Where do you want to go?',
            style: const TextStyle(fontSize: 15, color: AppColors.textMedium),
          ),
        ],
      ),
    );
  }
}
