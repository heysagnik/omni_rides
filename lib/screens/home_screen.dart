import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/map_style.dart';
import '../routes/app_router.dart';
import '../services/location_service.dart';
import '../services/location_guard_mixin.dart';
import '../services/ride_service.dart';
import 'home/widgets/home_widgets.dart';
import 'home/widgets/idle_body.dart';
import 'home/widgets/search_body.dart';

enum _Mode { idle, searching }

/// Maps a stored icon codePoint back to a constant [IconData].
/// Add entries here whenever a new icon type is saved to recent places.
IconData _iconFromCode(int code) {
  const map = <int, IconData>{
    0xe3ab: Icons.home_outlined,
    0xe318: Icons.home,
    0xe155: Icons.work_outlined,
    0xe943: Icons.work,
    0xe0c8: Icons.location_on,
    0xe0c7: Icons.location_on_outlined,
    0xe55f: Icons.star,
    0xe5f9: Icons.star_border,
    0xe532: Icons.favorite,
    0xe533: Icons.favorite_border,
    0xe540: Icons.flight,
    0xe530: Icons.fastfood,
    0xe56d: Icons.school,
    0xe88a: Icons.local_hospital,
    0xe8b4: Icons.restaurant,
    0xe7f0: Icons.person_pin_circle,
  };
  return map[code] ?? Icons.location_on_outlined;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with LocationGuardMixin<HomeScreen> {
  GoogleMapController? _mapController;
  _Mode _mode = _Mode.idle;

  final _pickupCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _pickupFocus = FocusNode();
  final _destFocus = FocusNode();

  String _activeField = 'destination';
  bool _isSearching = false;
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;
  double? _draggedHeight;
  bool _isDragging = false;

  static const _defaultCenter = LatLng(0.0, 0.0);

  List<PlaceItem> _recentPlaces = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _pickupFocus.addListener(_onPickupFocusChange);
    _destFocus.addListener(_onDestFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocation();
      _checkActiveRide();
    });
    initLocationGuard();
  }

  Future<void> _checkActiveRide() async {
    try {
      final appState = context.read<AppState>();
      final destination = await appState.checkAndRestoreActiveRide();
      if (!mounted) return;
      if (destination == 'searching') {
        Navigator.pushReplacementNamed(context, AppRouter.searching);
      } else if (destination == 'driverMatched') {
        Navigator.pushReplacementNamed(context, AppRouter.driverMatched);
      } else if (destination == 'inTransit') {
        Navigator.pushReplacementNamed(context, AppRouter.inTransit);
      }
    } catch (e) {
      debugPrint('[HomeScreen] _checkActiveRide error: $e');
    }
  }

  @override
  void dispose() {
    disposeLocationGuard();
    _pickupFocus.removeListener(_onPickupFocusChange);
    _destFocus.removeListener(_onDestFocusChange);
    _mapController?.dispose();
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    _pickupFocus.dispose();
    _destFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onPickupFocusChange() {
    if (_pickupFocus.hasFocus && _activeField != 'pickup') {
      setState(() { _activeField = 'pickup'; _suggestions = []; });
    }
  }

  void _onDestFocusChange() {
    if (_destFocus.hasFocus && _activeField != 'destination') {
      setState(() { _activeField = 'destination'; _suggestions = []; });
    }
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('recent_searches');
      if (list != null && list.isNotEmpty) {
        setState(() {
          _recentPlaces = list.map((item) {
            final map = jsonDecode(item) as Map<String, dynamic>;
            final iconCode = map['iconCode'] as int? ?? Icons.location_on_outlined.codePoint;
            return PlaceItem(
              map['name'] as String,
              map['subtitle'] as String,
              _iconFromCode(iconCode),
              lat: map['lat'] as double?,
              lng: map['lng'] as double?,
            );
          }).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _saveRecentSearch(String name, String subtitle, double lat, double lng) async {
    if (name.isEmpty) return;
    _recentPlaces.removeWhere((item) => item.name == name);
    _recentPlaces.insert(0, PlaceItem(name, subtitle, Icons.location_on_outlined, lat: lat, lng: lng));
    if (_recentPlaces.length > 5) _recentPlaces = _recentPlaces.sublist(0, 5);
    setState(() {});
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('recent_searches', _recentPlaces.map((item) => jsonEncode({
        'name': item.name,
        'subtitle': item.subtitle,
        'iconCode': item.icon.codePoint,
        'lat': item.lat,
        'lng': item.lng,
      })).toList());
    } catch (_) {}
  }

  Future<void> _initLocation() async {
    final state = context.read<AppState>();
    if (state.currentLat != 0) {
      _pickupCtrl.text = state.currentAddress;
      _moveCamera(LatLng(state.currentLat, state.currentLng));
      return;
    }
    final pos = await LocationService.getCurrentPosition();
    if (!mounted || pos == null) return;
    final addr = await LocationService.getAddressFromLatLng(pos.latitude, pos.longitude);
    final label = addr.isNotEmpty ? addr : 'Current Location';
    state.updateCurrentLocation(pos.latitude, pos.longitude, label);
    if (mounted) {
      _pickupCtrl.text = label;
      _moveCamera(LatLng(pos.latitude, pos.longitude));
    }
  }

  void _moveCamera(LatLng target) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 15)),
    );
  }

  void _fitRouteBounds() {
    final s = context.read<AppState>();
    if (_mapController == null || s.currentLat == 0 || s.destinationLat == 0) return;
    final minLat = s.currentLat < s.destinationLat ? s.currentLat : s.destinationLat;
    final maxLat = s.currentLat > s.destinationLat ? s.currentLat : s.destinationLat;
    final minLng = s.currentLng < s.destinationLng ? s.currentLng : s.destinationLng;
    final maxLng = s.currentLng > s.destinationLng ? s.currentLng : s.destinationLng;
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.006, minLng - 0.006),
          northeast: LatLng(maxLat + 0.006, maxLng + 0.006),
        ),
        80,
      ),
    );
  }

  void _enterSearch([PlaceItem? place]) {
    final state = context.read<AppState>();
    if (place != null) {
      if (place.lat != null && place.lng != null) {
        state.setDestination(place.name, place.lat!, place.lng!);
      }
    }
    Navigator.pushNamed(context, AppRouter.routeSelection);
  }

  void _exitSearch() {
    FocusScope.of(context).unfocus();
    setState(() { _mode = _Mode.idle; _suggestions = []; });
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {}

  void _onVerticalDragEnd(DragEndDetails details) {
    if (details.primaryVelocity != null && details.primaryVelocity! < -150) {
      Navigator.pushNamed(context, AppRouter.routeSelection);
    }
  }

  void _onType(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      final s = context.read<AppState>();
      final results = await RideService().searchLocations(
        query,
        lat: s.currentLat != 0 ? s.currentLat : null,
        lng: s.currentLng != 0 ? s.currentLng : null,
      );
      if (mounted) setState(() { _suggestions = results ?? []; _isSearching = false; });
    });
  }

  void _pick(Map<String, dynamic> loc) {
    final state = context.read<AppState>();
    final name = loc['name'] as String? ?? '';
    final address = loc['address'] as String? ?? '';
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
      _saveRecentSearch(name, address, lat, lng);
      if (state.pickupLat != 0) {
        _fitRouteBounds();
      } else {
        _moveCamera(LatLng(lat, lng));
      }
    }
  }

  bool get _canBook =>
      _pickupCtrl.text.isNotEmpty &&
      _pickupCtrl.text != 'Getting location…' &&
      _destCtrl.text.isNotEmpty;

  LatLng get _cameraTarget {
    final s = context.read<AppState>();
    return s.currentLat != 0 ? LatLng(s.currentLat, s.currentLng) : _defaultCenter;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final safeTop = MediaQuery.of(context).padding.top;
    final screenH = MediaQuery.of(context).size.height;
    final isSearchingMode = _mode == _Mode.searching;
    final defaultIdleH = screenH * 0.40;
    final cardH = _draggedHeight ?? (isSearchingMode ? screenH : defaultIdleH);
    final animDuration = _isDragging ? Duration.zero : const Duration(milliseconds: 300);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_mode == _Mode.searching) {
          _exitSearch();
          return;
        }

        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App'),
            content: const Text('Are you sure you want to exit the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Exit', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );

        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
          RepaintBoundary(
            child: GoogleMap(
              onMapCreated: (c) {
                _mapController = c;
                final s = context.read<AppState>();
                if (s.currentLat != 0) _moveCamera(LatLng(s.currentLat, s.currentLng));
              },
              initialCameraPosition: CameraPosition(target: _cameraTarget, zoom: 15),
              style: MapStyles.premiumStyle,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              padding: const EdgeInsets.only(bottom: 240),
              markers: {
                if (state.pickupLat != 0)
                  Marker(
                    markerId: const MarkerId('pickup'),
                    position: LatLng(state.pickupLat, state.pickupLng),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                    infoWindow: const InfoWindow(title: 'Pickup'),
                  ),
                if (state.destinationLat != 0)
                  Marker(
                    markerId: const MarkerId('destination'),
                    position: LatLng(state.destinationLat, state.destinationLng),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    infoWindow: const InfoWindow(title: 'Destination'),
                  ),
              },
            ),
          ),

          Positioned(
            top: 0, left: 0, right: 0, height: 100,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.2), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),

          AnimatedPositioned(
            duration: animDuration,
            curve: Curves.easeOutCubic,
            bottom: cardH + 12,
            right: 16,
            child: LocateFab(onTap: _initLocation),
          ),

          AnimatedPositioned(
            duration: animDuration,
            curve: Curves.easeOutCubic,
            bottom: 0, left: 0, right: 0,
            height: cardH,
            child: _BottomCard(
              mode: _mode,
              firstName: state.userName.isNotEmpty ? state.userName.split(' ').first : null,
              currentAddress: state.currentAddress,
              pickupCtrl: _pickupCtrl,
              destCtrl: _destCtrl,
              pickupFocus: _pickupFocus,
              destFocus: _destFocus,
              suggestions: _suggestions,
              isSearching: _isSearching,
              canBook: _canBook,
              recentPlaces: _recentPlaces,
              onSearchTap: _enterSearch,
              onBack: _exitSearch,
              onType: _onType,
              onPickSuggestion: _pick,
              onPickRecent: _enterSearch,
              onBook: () => Navigator.pushNamed(context, AppRouter.farePreview),
              onDragUpdate: _onVerticalDragUpdate,
              onDragEnd: _onVerticalDragEnd,
            ),
          ),

          AnimatedPositioned(
            duration: animDuration,
            curve: Curves.easeOutCubic,
            top: isSearchingMode ? -80 : safeTop + 12,
            left: 16, right: 16,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF111111).withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const LocationPulseDot(),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Consumer<AppState>(
                            builder: (_, s, __) => Text(
                              s.currentAddress.isNotEmpty ? _shortAddress(s.currentAddress) : 'Getting location…',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textMedium),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRouter.profile),
                  child: Container(
                    width: 44, height: 44,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight, AppColors.accent],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 10, offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(2),
                      child: ClipOval(
                        child: Consumer<AppState>(
                          builder: (_, s, __) => s.userPhotoUrl.isNotEmpty
                              ? Image.network(
                                  s.userPhotoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _AvatarFallback(name: s.userName),
                                )
                              : _AvatarFallback(name: s.userName),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      )
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String name;
  const _AvatarFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
  }
}

String _shortAddress(String address) {
  final parts = address.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  return parts.take(2).join(', ');
}

class _BottomCard extends StatelessWidget {
  final _Mode mode;
  final String? firstName;
  final String currentAddress;
  final TextEditingController pickupCtrl;
  final TextEditingController destCtrl;
  final FocusNode pickupFocus;
  final FocusNode destFocus;
  final List<Map<String, dynamic>> suggestions;
  final bool isSearching;
  final bool canBook;
  final List<PlaceItem> recentPlaces;
  final void Function(PlaceItem?) onSearchTap;
  final VoidCallback onBack;
  final ValueChanged<String> onType;
  final ValueChanged<Map<String, dynamic>> onPickSuggestion;
  final void Function(PlaceItem) onPickRecent;
  final VoidCallback onBook;
  final ValueChanged<DragUpdateDetails>? onDragUpdate;
  final ValueChanged<DragEndDetails>? onDragEnd;

  const _BottomCard({
    required this.mode,
    required this.firstName,
    required this.currentAddress,
    required this.pickupCtrl,
    required this.destCtrl,
    required this.pickupFocus,
    required this.destFocus,
    required this.suggestions,
    required this.isSearching,
    required this.canBook,
    required this.recentPlaces,
    required this.onSearchTap,
    required this.onBack,
    required this.onType,
    required this.onPickSuggestion,
    required this.onPickRecent,
    required this.onBook,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final isSearchingMode = mode == _Mode.searching;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Color(0x20000000), blurRadius: 28, offset: Offset(0, -6))],
      ),
      child: Column(
        children: [
          GestureDetector(
            onVerticalDragUpdate: onDragUpdate,
            onVerticalDragEnd: onDragEnd,
            behavior: HitTestBehavior.translucent,
            child: Container(
              width: double.infinity,
              color: Colors.transparent,
              child: Center(
                child: isSearchingMode
                    ? SizedBox(height: safeTop + 8)
                    : Container(
                        width: 40, height: 4,
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
              child: mode == _Mode.idle
                  ? IdleBody(
                      key: const ValueKey('idle'),
                      firstName: firstName,
                      currentAddress: currentAddress,
                      recentPlaces: recentPlaces,
                      onSearchTap: onSearchTap,
                      onDragUpdate: onDragUpdate,
                      onDragEnd: onDragEnd,
                    )
                  : SearchBody(
                      key: const ValueKey('search'),
                      pickupCtrl: pickupCtrl,
                      destCtrl: destCtrl,
                      pickupFocus: pickupFocus,
                      destFocus: destFocus,
                      suggestions: suggestions,
                      recentPlaces: recentPlaces,
                      isSearching: isSearching,
                      canBook: canBook,
                      onType: onType,
                      onPickSuggestion: onPickSuggestion,
                      onPickRecent: onPickRecent,
                      onBack: onBack,
                      onBook: onBook,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class LocationPulseDot extends StatefulWidget {
  const LocationPulseDot({super.key});

  @override
  State<LocationPulseDot> createState() => _LocationPulseDotState();
}

class _LocationPulseDotState extends State<LocationPulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 14, height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.15 + _controller.value * 0.25),
            ),
          ),
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
