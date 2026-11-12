import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/social_apps.dart';
import '../../core/theme/app_theme.dart';
import '../../services/usage_service.dart';
import '../../services/admob_service.dart';
import '../widgets/math_challenge_dialog.dart';

class AppSelectionScreen extends StatefulWidget {
  final bool isOnboarding;
  const AppSelectionScreen({super.key, this.isOnboarding = false});

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  final Set<String> _selectedPackages = {};
  final Set<String> _initialSelectedPackages = {};
  final Set<String> _pinnedTopPackages = {}; // Snapshot on open so items don't jump while tapping
  List<Map<String, String>> _installedApps = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int _activeTab = 0; // 0: All Apps (Initially selected pinned top), 1: Selected Only

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final savedList = prefs.getStringList('monitored_packages');

    final apps = await UsageService.getInstalledApps();
    final installedPackageSet = apps.map((a) => a['packageName'] ?? '').toSet();

    _selectedPackages.clear();
    if (savedList != null && savedList.isNotEmpty) {
      // User already has a custom saved list
      _selectedPackages.addAll(savedList);
    } else {
      // Initial onboarding / first run: Automatically select top social apps ONLY if they are installed on this device
      for (final defaultPkg in SocialApps.defaultPackageList) {
        if (installedPackageSet.contains(defaultPkg)) {
          _selectedPackages.add(defaultPkg);
        }
      }
    }

    _initialSelectedPackages
      ..clear()
      ..addAll(_selectedPackages);

    _pinnedTopPackages
      ..clear()
      ..addAll(_selectedPackages);

    if (mounted) {
      setState(() {
        _installedApps = apps;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSelection() async {
    final prefs = await SharedPreferences.getInstance();

    if (widget.isOnboarding) {
      // Step 2 of 3: Save chosen packages and return true so OnboardingDisclosureScreen advances to Step 3 (Permissions)
      await prefs.setStringList('monitored_packages', _selectedPackages.toList());
      if (mounted) {
        Navigator.of(context).pop(true);
      }
      return;
    }

    // If no changes were made, exit without asking math or showing ad
    if (setEquals(_selectedPackages, _initialSelectedPackages)) {
      if (mounted) {
        Navigator.of(context).pop(false);
      }
      return;
    }

    // Require mental math check only when committing in-app monitored app changes
    if (!mounted) return;
    MathChallengeDialog.show(
      context: context,
      actionDescription: 'save monitored apps changes',
      onSolved: _commitInAppSelection,
    );
  }

  Future<void> _commitInAppSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('monitored_packages', _selectedPackages.toList());

    // Update native service config
    final mode = prefs.getInt('focus_mode') ?? 1;
    final adultTrackingEnabled = prefs.getBool('adult_tracking_enabled') ?? true;
    final duration = prefs.getInt('oxygen_pass_duration_seconds') ?? 300;
    final limit = prefs.getInt('daily_limit_minutes') ?? 60;

    await UsageService.updateServiceConfig(
      mode: mode,
      adultTrackingEnabled: adultTrackingEnabled,
      passDuration: duration,
      dailyLimit: limit,
      packages: _selectedPackages.toList(),
    );

    // Natural checkpoint: trigger throttled interstitial ad (normal settings usage only)
    AdMobService.instance.showInterstitialIfAllowed();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Monitored apps updated successfully!'),
          backgroundColor: AppTheme.mint,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  Widget _buildFilterChip(int index, String label, int count, IconData icon) {
    final isActive = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          if (_activeTab != index && index == 0) {
            _pinnedTopPackages
              ..clear()
              ..addAll(_selectedPackages);
          }
          _activeTab = index;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.mint.withValues(alpha: 0.15) : AppTheme.surfaceCard(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? AppTheme.mint : AppTheme.cardBorder(context),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? AppTheme.mint : AppTheme.textSecondary(context),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '$label ($count)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive ? AppTheme.mint : AppTheme.textSecondary(context),
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Filter by search query and active tab
    final filteredApps = _installedApps.where((app) {
      final name = app['appName']?.toLowerCase() ?? '';
      final pkg = app['packageName']?.toLowerCase() ?? '';
      final matchesSearch = name.contains(_searchQuery.toLowerCase()) || pkg.contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;
      if (_activeTab == 1) {
        return _selectedPackages.contains(pkg);
      }
      return true;
    }).toList();

    // 2. Sort: Apps pinned on screen open stay at the top so items don't jump while tapping
    filteredApps.sort((a, b) {
      final aPinned = _pinnedTopPackages.contains(a['packageName'] ?? '');
      final bPinned = _pinnedTopPackages.contains(b['packageName'] ?? '');
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      final aName = a['appName'] ?? '';
      final bName = b['appName'] ?? '';
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    });

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        title: Text(widget.isOnboarding
            ? 'Select Apps to Track (${_selectedPackages.length})'
            : 'Monitored Apps (${_selectedPackages.length})'),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppTheme.mint),
                  const SizedBox(height: 16),
                  Text(
                    'Scanning installed apps...',
                    style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 14),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                if (widget.isOnboarding)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.mint.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.mint.withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          'STEP 2 OF 3 • SELECT APPS TO TRACK',
                          style: TextStyle(
                            color: AppTheme.mint,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: AppTheme.textPrimary(context)),
                    decoration: InputDecoration(
                      hintText: 'Search installed apps...',
                      hintStyle: TextStyle(color: AppTheme.textMuted(context)),
                      prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary(context)),
                      filled: true,
                      fillColor: AppTheme.surfaceCard(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: AppTheme.cardBorder(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: AppTheme.cardBorder(context)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: AppTheme.mint),
                      ),
                    ),
                  ),
                ),

                // Quick Filter Tabs: All Apps vs Selected Only
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      _buildFilterChip(0, 'All Apps', _installedApps.length, Icons.apps_rounded),
                      const SizedBox(width: 10),
                      _buildFilterChip(1, 'Selected Only', _selectedPackages.length, Icons.check_circle_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // List Header with Context Info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _activeTab == 1
                            ? 'Selected Monitored Apps (${filteredApps.length})'
                            : 'All Apps (Selected at top)',
                        style: TextStyle(
                          color: AppTheme.textPrimary(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_selectedPackages.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => _selectedPackages.clear()),
                          child: const Text(
                            'Clear All',
                            style: TextStyle(color: AppTheme.glitchCoral, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),

                // Installed apps list
                Expanded(
                  child: filteredApps.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _activeTab == 1 ? Icons.check_circle_outline_rounded : Icons.search_off_rounded,
                                  size: 48,
                                  color: AppTheme.textMuted(context),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _activeTab == 1
                                      ? 'No monitored apps selected yet.\nSwitch to "All Apps" to select apps.'
                                      : 'No apps found matching "$_searchQuery"',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppTheme.textMuted(context), fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredApps.length,
                          itemBuilder: (context, index) {
                            final app = filteredApps[index];
                            final pkg = app['packageName'] ?? '';
                            final name = app['appName'] ?? pkg;
                            final isSelected = _selectedPackages.contains(pkg);

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.surfaceCard(context) : AppTheme.surfaceCard(context).withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? AppTheme.mint.withValues(alpha: 0.6) : AppTheme.cardBorder(context),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: CheckboxListTile(
                                value: isSelected,
                                activeColor: AppTheme.mint,
                                checkColor: Colors.black,
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          color: isSelected ? AppTheme.mint : AppTheme.textPrimary(context),
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.mint.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'Active',
                                          style: TextStyle(color: AppTheme.mint, fontSize: 10, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  pkg,
                                  style: TextStyle(color: AppTheme.textMuted(context), fontSize: 11),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedPackages.add(pkg);
                                    } else {
                                      _selectedPackages.remove(pkg);
                                    }
                                  });
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedPackages.isEmpty ? AppTheme.surfaceCard(context) : AppTheme.mint,
                foregroundColor: _selectedPackages.isEmpty ? AppTheme.textMuted(context) : Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              ),
              onPressed: _selectedPackages.isEmpty ? null : _saveSelection,
              child: Text(
                widget.isOnboarding
                    ? (_selectedPackages.isEmpty
                        ? 'Select at least 1 app to track'
                        : 'Next: Privacy & Permissions')
                    : 'Apply Monitored Apps (${_selectedPackages.length})',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
