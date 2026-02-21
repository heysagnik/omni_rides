import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';
import '../widgets/service_selector.dart';

class RouteSelectionScreen extends StatefulWidget {
  const RouteSelectionScreen({super.key});

  @override
  State<RouteSelectionScreen> createState() => _RouteSelectionScreenState();
}

class _RouteSelectionScreenState extends State<RouteSelectionScreen>
    with SingleTickerProviderStateMixin {
  final _pickupCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  late AnimationController _animCtrl;

  // Predefined destinations for demo
  static const List<Map<String, dynamic>> _suggestions = [
    {
      'name': 'India Gate',
      'area': 'Rajpath, New Delhi',
      'lat': 28.6129,
      'lng': 77.2295,
    },
    {
      'name': 'Lotus Temple',
      'area': 'Bahapur, New Delhi',
      'lat': 28.5535,
      'lng': 77.2588,
    },
    {
      'name': 'Qutub Minar',
      'area': 'Mehrauli, New Delhi',
      'lat': 28.5245,
      'lng': 77.1855,
    },
    {
      'name': 'Red Fort',
      'area': 'Chandni Chowk, Old Delhi',
      'lat': 28.6562,
      'lng': 77.2410,
    },
    {
      'name': 'Connaught Place',
      'area': 'Central Delhi',
      'lat': 28.6315,
      'lng': 77.2167,
    },
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    final state = context.read<AppState>();
    _pickupCtrl.text = state.pickupAddress.isNotEmpty
        ? state.pickupAddress
        : state.currentAddress;
  }

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _selectDestination(Map<String, dynamic> dest) {
    final state = context.read<AppState>();
    _destCtrl.text = '${dest['name']}, ${dest['area']}';
    state.setDestination(
      '${dest['name']}, ${dest['area']}',
      dest['lat'] as double,
      dest['lng'] as double,
    );
    setState(() {});
  }

  void _findDriver() {
    final state = context.read<AppState>();
    if (state.destinationAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a destination'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    state.startSearching();
    Navigator.pushReplacementNamed(context, '/searching');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Plan your trip'),
      ),
      body: FadeTransition(
        opacity: _animCtrl,
        child: Column(
          children: [
            // Route Inputs
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Pickup
                  Row(
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          Container(
                            width: 2,
                            height: 30,
                            color: AppColors.divider,
                          ),
                          const Icon(
                            Icons.location_on,
                            color: AppColors.error,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _pickupCtrl,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Pickup point',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                filled: true,
                                fillColor: AppColors.backgroundGrey,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _destCtrl,
                              autofocus: true,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: 'To where?',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                filled: true,
                                fillColor: AppColors.backgroundGrey,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                suffixIcon: _destCtrl.text.isNotEmpty
                                    ? IconButton(
                                        onPressed: () {
                                          _destCtrl.clear();
                                          setState(() {});
                                        },
                                        icon: const Icon(
                                          Icons.close,
                                          size: 20,
                                          color: AppColors.textMedium,
                                        ),
                                      )
                                    : null,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Service Selector
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Service Type',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ServiceSelector(
              selected: state.selectedService,
              onSelected: (s) => state.setSelectedService(s),
            ),

            const SizedBox(height: 16),
            const Divider(indent: 20, endIndent: 20),
            const SizedBox(height: 8),

            // Destination Suggestions
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final dest = _suggestions[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.primaryGreen,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      dest['name'] as String,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    subtitle: Text(
                      dest['area'] as String,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMedium,
                      ),
                    ),
                    onTap: () => _selectDestination(dest),
                  );
                },
              ),
            ),

            // Fare & Action
            if (state.destinationAddress.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Estimated Fare',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMedium,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${state.estimatedFare.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundGrey,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${state.estimatedDistance} km',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      text: 'Find a driver',
                      icon: Icons.search_rounded,
                      onPressed: _findDriver,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
