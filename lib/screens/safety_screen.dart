import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../services/safety_service.dart';

class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key});

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> {
  final SafetyService _safetyService = SafetyService();
  List<Map<String, dynamic>> _contacts = [];
  bool _loadingContacts = true;
  bool _sosBusy = false;
  bool _shareBusy = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _loadingContacts = true);
    final contacts = await _safetyService.getContacts();
    if (mounted) {
      setState(() {
        _contacts = contacts ?? [];
        _loadingContacts = false;
      });
    }
  }

  // ── SOS ────────────────────────────────────────────────────────────────────

  void _showSOSConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 10),
            Text('Activate SOS?'),
          ],
        ),
        content: const Text(
          'This will alert your emergency contacts and share your live location. Use only in genuine emergencies.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _triggerSos();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Activate'),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerSos() async {
    setState(() => _sosBusy = true);
    final state = context.read<AppState>();
    final ok = await _safetyService.triggerSos(
      rideId: state.rideId.isNotEmpty ? state.rideId : null,
    );
    if (!mounted) return;
    setState(() => _sosBusy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? '🆘 SOS activated — contacts alerted'
          : 'Failed to send SOS. Please try again.'),
      backgroundColor: ok ? AppColors.error : AppColors.textMedium,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Share Trip ─────────────────────────────────────────────────────────────

  Future<void> _shareTrip() async {
    final rideId = context.read<AppState>().rideId;
    if (rideId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No active ride to share.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _shareBusy = true);
    final result = await _safetyService.shareTrip(rideId);
    if (!mounted) return;
    setState(() => _shareBusy = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not generate share link.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final shareUrl = result['shareUrl'] as String? ?? '';
    if (shareUrl.isNotEmpty) {
      await Share.share('Track my ride live: $shareUrl');
    }
  }

  // ── Contacts ───────────────────────────────────────────────────────────────

  void _showAddContactSheet() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Add Emergency Contact',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              const SizedBox(height: 20),
              _field(controller: nameCtrl, hint: 'Full name', icon: Icons.person_outline),
              const SizedBox(height: 12),
              _field(controller: phoneCtrl, hint: 'Phone number (+91...)', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _field(controller: relCtrl, hint: 'Relationship (optional)', icon: Icons.people_outline),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty ||
                        phoneCtrl.text.trim().isEmpty) { return; }
                    Navigator.pop(ctx);
                    final contact = await _safetyService.addContact(
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      relationship: relCtrl.text.trim().isNotEmpty
                          ? relCtrl.text.trim()
                          : null,
                    );
                    if (contact != null && mounted) {
                      setState(() => _contacts.add(contact));
                    }
                  },
                  child: const Text('Save Contact',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextField _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.textMedium, size: 20),
        filled: true,
        fillColor: AppColors.backgroundGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Future<void> _deleteContact(String contactId) async {
    final ok = await _safetyService.deleteContact(contactId);
    if (ok && mounted) {
      setState(() => _contacts.removeWhere((c) => c['id'] == contactId));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Safety'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Emergency SOS Banner ──────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.error,
                    AppColors.error.withValues(alpha: 0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sos_rounded,
                        size: 36, color: AppColors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text('Emergency SOS',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.white)),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to alert emergency contacts\nand share your live location',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        color: AppColors.white.withValues(alpha: 0.85),
                        height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _sosBusy ? null : _showSOSConfirmation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.white,
                        foregroundColor: AppColors.error,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _sosBusy
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.error))
                          : const Text('Activate SOS',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Quick Actions ─────────────────────────────────────────────
            const Text('Quick Actions',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.phone_in_talk_rounded,
                    label: 'Call Police',
                    subtitle: '112',
                    color: AppColors.error,
                    onTap: () => _showCallSnack('Police', '112'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.local_hospital_rounded,
                    label: 'Ambulance',
                    subtitle: '108',
                    color: AppColors.warning,
                    onTap: () => _showCallSnack('Ambulance', '108'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.share_location_rounded,
                    label: 'Share Ride',
                    subtitle: _shareBusy ? '…' : 'Live',
                    color: AppColors.primaryGreen,
                    onTap: _shareBusy ? () {} : _shareTrip,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── Trusted Contacts ──────────────────────────────────────────
            const Text('Trusted Contacts',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 4),
            Text('Auto-notified during SOS activation',
                style: TextStyle(fontSize: 13, color: AppColors.textMedium)),
            const SizedBox(height: 14),

            if (_loadingContacts)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else ...[
              ..._contacts.map((c) => _ContactTile(
                    contact: c,
                    onDelete: () => _deleteContact(c['id'] as String),
                  )),
              _AddContactTile(onTap: _showAddContactSheet),
            ],

            const SizedBox(height: 28),

            // ── Safety Tips ───────────────────────────────────────────────
            const Text('Safety Tips',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 14),
            const _SafetyTip(
              icon: Icons.pin_rounded,
              title: 'Verify OTP',
              description:
                  'Always match the 4-digit OTP with your driver before boarding.',
            ),
            const _SafetyTip(
              icon: Icons.share_rounded,
              title: 'Share your ride',
              description:
                  'Share trip details with family or friends for real-time tracking.',
            ),
            const _SafetyTip(
              icon: Icons.route_rounded,
              title: 'Follow the route',
              description:
                  'Monitor the route on the map to ensure the driver stays on track.',
            ),
            const _SafetyTip(
              icon: Icons.nightlight_round,
              title: 'Night safety',
              description:
                  'Prefer well-lit pickup/drop points and sit in the back seat at night.',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showCallSnack(String service, String number) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Calling $service ($number)…'),
      backgroundColor: AppColors.primaryGreen,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final Map<String, dynamic> contact;
  final VoidCallback onDelete;

  const _ContactTile({required this.contact, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = contact['name'] as String? ?? '';
    final phone = contact['phone'] as String? ?? '';
    final rel = contact['relationship'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrey,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text(
                  [phone, if (rel.isNotEmpty) rel].join('  •  '),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMedium),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error, size: 20),
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Remove contact?'),
                content: Text('Remove $name from emergency contacts?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onDelete();
                    },
                    child: const Text('Remove',
                        style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddContactTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddContactTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_add_rounded,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text('Add Emergency Contact',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ),
            const Icon(Icons.add_rounded, color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

class _SafetyTip extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _SafetyTip({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundGrey,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primaryGreen, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark)),
                  const SizedBox(height: 4),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMedium,
                          height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
