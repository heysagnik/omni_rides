import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../routes/app_router.dart';
import '../services/ride_service.dart';
import '../theme/app_colors.dart';

class FarePreviewScreen extends StatefulWidget {
  const FarePreviewScreen({super.key});

  @override
  State<FarePreviewScreen> createState() => _FarePreviewScreenState();
}

class _FarePreviewScreenState extends State<FarePreviewScreen> {
  final _rideService = RideService();
  final _couponCtrl = TextEditingController();

  bool _loading = true;
  String? _error;

  double _distanceKm = 0;
  double _durationMin = 0;
  int _bikeFare = 0;
  int _autoFare = 0;
  int _parcelFare = 0;
  double _surgeMult = 1.0;
  String _surgeReason = '';

  String? _appliedCoupon;
  int _discountAmount = 0;
  bool _couponLoading = false;
  String? _couponError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchEstimates();
    });
  }

  @override
  void dispose() {
    _couponCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchEstimates() async {
    final state = context.read<AppState>();
    setState(() { _loading = true; _error = null; });

    final data = await _rideService.getFareEstimates(
      pickupLat: state.pickupLat,
      pickupLng: state.pickupLng,
      dropLat: state.destinationLat,
      dropLng: state.destinationLng,
    );

    if (!mounted) return;

    if (data == null) {
      setState(() { _loading = false; _error = 'Could not fetch prices. Check your connection.'; });
      return;
    }

    final options = data['options'] as Map<String, dynamic>? ?? {};
    final bike   = options['bike']   as Map<String, dynamic>? ?? {};
    final auto   = options['auto']   as Map<String, dynamic>? ?? {};
    final parcel = options['parcel'] as Map<String, dynamic>? ?? {};
    final bikeBreakdown = bike['breakdown'] as Map<String, dynamic>? ?? {};

    setState(() {
      _loading     = false;
      _distanceKm  = (data['distanceKm'] as num?)?.toDouble() ?? 0;
      _durationMin = (data['durationMin'] as num?)?.toDouble() ?? 0;
      _bikeFare    = (bike['estimatedFare']   as num?)?.toInt() ?? 0;
      _autoFare    = (auto['estimatedFare']   as num?)?.toInt() ?? 0;
      _parcelFare  = (parcel['estimatedFare'] as num?)?.toInt() ?? 0;
      _surgeMult   = (bikeBreakdown['surgeMultiplier'] as num?)?.toDouble() ?? 1.0;
      _surgeReason = (bikeBreakdown['surgeReason'] as String?) ?? '';
    });
  }

  Future<void> _applyCoupon() async {
    final code = _couponCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    final selectedType = context.read<AppState>().selectedRideType;
    final baseFare = selectedType == 'parcel' ? _parcelFare : (selectedType == 'auto' ? _autoFare : _bikeFare);

    setState(() { _couponLoading = true; _couponError = null; });

    final result = await _rideService.validateCoupon(
      code: code,
      fare: baseFare,
    );

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _couponLoading = false;
        _couponError = 'Could not validate coupon. Try again.';
      });
      return;
    }

    if (result.containsKey('error')) {
      setState(() {
        _couponLoading = false;
        _couponError = result['error'] as String? ?? 'Invalid coupon code.';
        _appliedCoupon = null;
        _discountAmount = 0;
      });
    } else {
      setState(() {
        _couponLoading = false;
        _appliedCoupon = code;
        _discountAmount = (result['discount'] as num?)?.toInt() ?? 0;
        _couponError = null;
      });
      HapticFeedback.lightImpact();
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _discountAmount = 0;
      _couponCtrl.clear();
      _couponError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final selectedType = state.selectedRideType;
    final baseFare = selectedType == 'parcel' ? _parcelFare : (selectedType == 'auto' ? _autoFare : _bikeFare);
    final finalFare = (baseFare - _discountAmount).clamp(0, baseFare);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          // ── Header ───────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    color: AppColors.textDark,
                  ),
                  Text(
                    'Choose a ride',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Route summary ────────────────────────────────────
          _RouteSummary(
            pickup: state.pickupAddress,
            destination: state.destinationAddress,
            distanceKm: _distanceKm,
            durationMin: _durationMin,
          ),
          
          const Divider(height: 1, thickness: 1, color: AppColors.backgroundGrey),

          // ── Content ──────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(PhosphorIconsRegular.warningCircle, size: 48, color: AppColors.error),
                            const SizedBox(height: 16),
                            Text(_error!, style: GoogleFonts.inter(color: AppColors.textMedium)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchEstimates,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: Text('Retry', style: GoogleFonts.inter(color: AppColors.white, fontWeight: FontWeight.w600)),
                            )
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        children: [
                          if (_surgeMult > 1.0)
                            _SurgeBanner(reason: _surgeReason, multiplier: _surgeMult),

                          // Omni Bike card
                          _RideOptionCard(
                            imageAsset: 'assets/images/motorcycle-svgrepo-com.png',
                            title: 'omniMU Bike',
                            description: 'Quick and affordable bike ride',
                            fare: _bikeFare,
                            durationMin: _durationMin.round(),
                            isSelected: selectedType == 'bike' || selectedType == 'human',
                            onTap: () {
                              context.read<AppState>().setSelectedRideType('bike');
                              if (_appliedCoupon != null) _removeCoupon();
                            },
                          ),

                          const SizedBox(height: 12),

                          // Omni Auto card
                          _RideOptionCard(
                            imageAsset: 'assets/images/auto-rickshaw-svgrepo-com.png',
                            title: 'omniMU Auto',
                            description: 'Comfortable auto ride, up to 3 passengers',
                            fare: _autoFare,
                            durationMin: _durationMin.round(),
                            isSelected: selectedType == 'auto',
                            onTap: () {
                              context.read<AppState>().setSelectedRideType('auto');
                              if (_appliedCoupon != null) _removeCoupon();
                            },
                          ),

                          const SizedBox(height: 12),

                          // Omni Parcel card
                          _RideOptionCard(
                            imageAsset: 'assets/images/package-svgrepo-com.png',
                            title: 'omniMU Parcel',
                            description: 'Send packages across the city',
                            fare: _parcelFare,
                            durationMin: _durationMin.round(),
                            isSelected: selectedType == 'parcel',
                            onTap: () {
                              context.read<AppState>().setSelectedRideType('parcel');
                              if (_appliedCoupon != null) _removeCoupon();
                            },
                          ),

                          const SizedBox(height: 28),

                          // ── Coupon code ───────────────────────
                          Text(
                            'Coupon code',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 10),

                          _CouponField(
                            controller: _couponCtrl,
                            isLoading: _couponLoading,
                            isApplied: _appliedCoupon != null,
                            error: _couponError,
                            discountAmount: _discountAmount,
                            onApply: _applyCoupon,
                            onRemove: _removeCoupon,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
          ),

          // ── Confirm button ───────────────────────────────────
          if (!_loading && _error == null)
            _ConfirmBar(
              baseFare: baseFare,
              finalFare: finalFare,
              hasDiscount: _discountAmount > 0,
              onConfirm: () {
                final s = context.read<AppState>();
                s.setEstimatedFare(finalFare.toDouble());
                s.setAppliedCoupon(_appliedCoupon ?? '');
                Navigator.pushNamed(context, AppRouter.searching);
              },
            ),
        ],
      ),
    );
  }
}

// ── Route Summary ─────────────────────────────────────────────────────────────

class _RouteSummary extends StatelessWidget {
  final String pickup;
  final String destination;
  final double distanceKm;
  final double durationMin;

  const _RouteSummary({
    required this.pickup,
    required this.destination,
    required this.distanceKm,
    required this.durationMin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          Column(
            children: [
              Container(width: 10, height: 10,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
              Container(width: 2, height: 24, color: AppColors.divider),
              Container(width: 10, height: 10,
                decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(2))),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pickup,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark)),
                const SizedBox(height: 14),
                Text(destination,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (distanceKm > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.backgroundGrey,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${distanceKm.toStringAsFixed(1)} km · ${durationMin.round()} min',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMedium),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Surge Banner ──────────────────────────────────────────────────────────────

class _SurgeBanner extends StatelessWidget {
  final String reason;
  final double multiplier;
  const _SurgeBanner({required this.reason, required this.multiplier});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(PhosphorIconsRegular.lightning, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${multiplier.toStringAsFixed(1)}× surge · $reason',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ride Option Card ──────────────────────────────────────────────────────────

class _RideOptionCard extends StatelessWidget {
  final String imageAsset;
  final String title;
  final String description;
  final int fare;
  final int durationMin;
  final bool isSelected;
  final VoidCallback onTap;

  const _RideOptionCard({
    required this.imageAsset,
    required this.title,
    required this.description,
    required this.fare,
    required this.durationMin,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.backgroundGrey,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Image.asset(
                  imageAsset,
                  width: 32,
                  height: 32,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  const SizedBox(height: 2),
                  Text(description,
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMedium)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(PhosphorIconsRegular.clock, size: 12, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text('~$durationMin min',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textLight)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹$fare',
                  style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: isSelected ? AppColors.primary : AppColors.textDark)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Coupon Field ──────────────────────────────────────────────────────────────

class _CouponField extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final bool isApplied;
  final String? error;
  final int discountAmount;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  const _CouponField({
    required this.controller,
    required this.isLoading,
    required this.isApplied,
    required this.error,
    required this.discountAmount,
    required this.onApply,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                readOnly: isApplied,
                textCapitalization: TextCapitalization.characters,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  letterSpacing: 1.2,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter coupon code',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textLight,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w400,
                  ),
                  filled: true,
                  fillColor: isApplied
                      ? AppColors.primary.withValues(alpha: 0.06)
                      : AppColors.backgroundGrey,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: isApplied
                        ? const BorderSide(color: AppColors.primary, width: 1.5)
                        : BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Icon(
                      PhosphorIconsRegular.ticket,
                      size: 18,
                      color: isApplied ? AppColors.primary : AppColors.textMedium,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 40),
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isApplied
                  ? _ActionBtn(
                      key: const ValueKey('remove'),
                      label: 'Remove',
                      color: AppColors.error,
                      onTap: onRemove,
                    )
                  : isLoading
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          width: 72, height: 48,
                          child: Center(
                            child: SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary)),
                          ))
                      : _ActionBtn(
                          key: const ValueKey('apply'),
                          label: 'Apply',
                          color: AppColors.primary,
                          onTap: onApply,
                        ),
            ),
          ],
        ),

        if (isApplied && discountAmount > 0) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
              const SizedBox(width: 6),
              Text(
                'You save ₹$discountAmount on this ride!',
                style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success),
              ),
            ],
          ),
        ],

        if (error != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.error),
              const SizedBox(width: 6),
              Text(error!,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.error)),
            ],
          ),
        ],
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        child: Text(label,
          style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }
}

// ── Confirm Bar ───────────────────────────────────────────────────────────────

class _ConfirmBar extends StatelessWidget {
  final int baseFare;
  final int finalFare;
  final bool hasDiscount;
  final VoidCallback onConfirm;

  const _ConfirmBar({
    required this.baseFare,
    required this.finalFare,
    required this.hasDiscount,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total fare',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMedium),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹$finalFare',
                    style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark, height: 1.1),
                  ),
                  if (hasDiscount) ...[
                    const SizedBox(width: 6),
                    Text(
                      '₹$baseFare',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textLight,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Confirm Ride',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
