import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../routes/app_router.dart';
import '../services/location_service.dart';
import '../services/ride_service.dart';
import 'home/widgets/home_widgets.dart';
import 'home/widgets/idle_body.dart';
import 'home/widgets/search_body.dart';

enum _Mode { idle, searching }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  static const _benguluruCenter = LatLng(12.9716, 77.5946);

  static const _recentPlaces = [
    PlaceItem('Koramangala', '6th Block, Bengaluru', Icons.work_outline_rounded),
    PlaceItem('Indiranagar', '100 Feet Road, Bengaluru', Icons.home_outlined),
    PlaceItem('MG Road', 'Brigade Road, Bengaluru', Icons.shopping_bag_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _pickupFocus.addListener(() {
      if (_pickupFocus.hasFocus && _activeField != 'pickup') {
        setState(() {
          _activeField = 'pickup';
          _suggestions = [];
        });
      }
    });
    _destFocus.addListener(() {
      if (_destFocus.hasFocus && _activeField != 'destination') {
        setState(() {
          _activeField = 'destination';
          _suggestions = [];
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLocation());
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    _pickupFocus.dispose();
    _destFocus.dispose();
    _debounce?.cancel();
    super.dispose();
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
    final addr =
        await LocationService.getAddressFromLatLng(pos.latitude, pos.longitude);
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

  void _enterSearch([PlaceItem? place]) {
    final state = context.read<AppState>();
    if (_pickupCtrl.text.isEmpty && state.currentAddress.isNotEmpty) {
      _pickupCtrl.text = state.currentAddress;
    }
    setState(() {
      _mode = _Mode.searching;
      _activeField = 'destination';
      if (place != null) {
        _destCtrl.text = place.name;
        // Check if both fields are available to make it bookable right away
      }
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) FocusScope.of(context).requestFocus(_destFocus);
    });
  }

  void _exitSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _mode = _Mode.idle;
      _suggestions = [];
    });
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
      if (mounted) {
        setState(() {
          _suggestions = results ?? [];
          _isSearching = false;
        });
      }
    });
  }

  void _pick(Map<String, dynamic> loc) {
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
      _moveCamera(LatLng(lat, lng));
    }
  }

  bool get _canBook =>
      _pickupCtrl.text.isNotEmpty &&
      _pickupCtrl.text != 'Getting location…' &&
      _destCtrl.text.isNotEmpty;

  LatLng get _cameraTarget {
    final s = context.read<AppState>();
    return s.currentLat != 0
        ? LatLng(s.currentLat, s.currentLng)
        : _benguluruCenter;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final safeTop = MediaQuery.of(context).padding.top;
    final screenH = MediaQuery.of(context).size.height;
    final cardH = screenH * 0.52;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Full-screen Google Map ─────────────────────────────────────
          GoogleMap(
            onMapCreated: (c) {
              _mapController = c;
              final s = context.read<AppState>();
              if (s.currentLat != 0) {
                _moveCamera(LatLng(s.currentLat, s.currentLng));
              }
            },
            initialCameraPosition:
                CameraPosition(target: _cameraTarget, zoom: 15),
            style: _mapStyle,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            padding: EdgeInsets.only(bottom: cardH - 24),
            markers: state.currentLat != 0
                ? {
                    Marker(
                      markerId: const MarkerId('pickup'),
                      position: LatLng(state.currentLat, state.currentLng),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueGreen),
                    ),
                  }
                : {},
          ),

          // ── Top gradient — depth over map ────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 100,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Locate Me FAB — sits just above the card ─────────────────────
          Positioned(
            bottom: cardH + 12,
            right: 16,
            child: LocateFab(onTap: _initLocation),
          ),

          // ── Bottom card ───────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: cardH,
            child: _BottomCard(
              mode: _mode,
              firstName: state.userName.isNotEmpty
                  ? state.userName.split(' ').first
                  : null,
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
              onBook: () =>
                  Navigator.pushNamed(context, AppRouter.searching),
            ),
          ),

          // ── Floating top bar — location + account avatar ─────────────────
          Positioned(
            top: safeTop + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Location pill
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 12,
                            offset: Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Consumer<AppState>(
                            builder: (_, s, __) => Text(
                              s.currentAddress.isNotEmpty
                                  ? _shortAddress(s.currentAddress)
                                  : 'Getting location…',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 18, color: Color(0xFF888888)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Account avatar button
                GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, AppRouter.profile),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 12,
                            offset: Offset(0, 3)),
                      ],
                    ),
                    child: Consumer<AppState>(
                      builder: (_, s, __) => ClipOval(
                        child: s.userPhotoUrl.isNotEmpty
                            ? Image.network(s.userPhotoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _AvatarFallback(name: s.userName))
                            : _AvatarFallback(name: s.userName),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Avatar fallback ─────────────────────────────────────────────────────────

class _AvatarFallback extends StatelessWidget {
  final String name;
  const _AvatarFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color: AppColors.primary,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _shortAddress(String address) {
  final parts = address.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  return parts.take(2).join(', ');
}

// ─── Bottom card ─────────────────────────────────────────────────────────────

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
  final VoidCallback onBook;

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
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Color(0x20000000), blurRadius: 28, offset: Offset(0, -6)),
        ],
      ),
      child: Column(
        children: [
          // Pill handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: mode == _Mode.idle
                  ? IdleBody(
                      key: const ValueKey('idle'),
                      firstName: firstName,
                      currentAddress: currentAddress,
                      recentPlaces: recentPlaces,
                      onSearchTap: onSearchTap,
                    )
                  : SearchBody(
                      key: const ValueKey('search'),
                      pickupCtrl: pickupCtrl,
                      destCtrl: destCtrl,
                      pickupFocus: pickupFocus,
                      destFocus: destFocus,
                      suggestions: suggestions,
                      isSearching: isSearching,
                      canBook: canBook,
                      onType: onType,
                      onPickSuggestion: onPickSuggestion,
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

const String _mapStyle = '''
[
  {"featureType":"all","elementType":"geometry","stylers":[{"color":"#f0ede8"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#b8d8ea"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#7ca8c0"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#ffe082"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#f0c040","weight":0.5}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#6b6b6b"}]},
  {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#d4e8c8"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#444444"}]},
  {"featureType":"administrative.neighborhood","elementType":"labels.text.fill","stylers":[{"color":"#888888"}]},
  {"featureType":"landscape.man_made","elementType":"geometry","stylers":[{"color":"#e8e4de"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#e4edd8"}]}
]
''';