import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../services/usage_service.dart';
import '../widgets/parent_pin_dialog.dart';

class KidsModeSetupScreen extends StatefulWidget {
  const KidsModeSetupScreen({super.key});

  @override
  State<KidsModeSetupScreen> createState() => _KidsModeSetupScreenState();
}

class _KidsModeSetupScreenState extends State<KidsModeSetupScreen> {
  final Set<String> _allowedPackages = {};
  final Set<String> _pinnedTopPackages = {};
  List<Map<String, String>> _installedApps = [];
  int _kidsLimitMinutes = 30;
  bool _hasPinSet = false;
  bool _isLoading = true;
  String _searchQuery = '';
  int _activeTab = 0; // 0: All Apps, 1: Allowed Only

  final List<int> _presetLimits = [15, 30, 45, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final savedAllowed = prefs.getStringList('kids_allowed_packages') ?? ['com.google.android.youtube'];
    final savedLimit = prefs.getInt('kids_limit_minutes') ?? 30;
    final savedPin = prefs.getString('parent_pin_code') ?? '';

    _allowedPackages
      ..clear()
      ..addAll(savedAllowed);
    _pinnedTopPackages
      ..clear()
      ..addAll(savedAllowed);
    _kidsLimitMinutes = savedLimit;
    _hasPinSet = savedPin.length == 4;

    final apps = await UsageService.getInstalledApps();
    if (mounted) {
      setState(() {
        _installedApps = apps;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('kids_allowed_packages', _allowedPackages.toList());
    await prefs.setInt('kids_limit_minutes', _kidsLimitMinutes);

    final status = await UsageService.getKidsModeStatus();
    final bool isActive = (status['isActive'] as bool?) ?? false;
    final int remainingSecs = isActive
        ? ((status['remainingSeconds'] as num?)?.toInt() ?? (_kidsLimitMinutes * 60))
        : (_kidsLimitMinutes * 60);

    await UsageService.setKidsMode(
      active: isActive,
      limitMinutes: _kidsLimitMinutes,
      remainingSeconds: remainingSecs,
      allowedPackages: _allowedPackages.toList(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kids Mode settings saved!'),
          backgroundColor: AppTheme.cyan,
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
              ..addAll(_allowedPackages);
          }
          _activeTab = index;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.cyan.withValues(alpha: 0.15) : AppTheme.surfaceCard(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? AppTheme.cyan : AppTheme.cardBorder(context),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? AppTheme.cyan : AppTheme.textSecondary(context),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '$label ($count)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive ? AppTheme.cyan : AppTheme.textSecondary(context),
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
    final filteredApps = _installedApps.where((app) {
      final name = app['appName']?.toLowerCase() ?? '';
      final pkg = app['packageName']?.toLowerCase() ?? '';
      final matchesSearch = name.contains(_searchQuery.toLowerCase()) || pkg.contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;
      if (_activeTab == 1) {
        return _allowedPackages.contains(pkg);
      }
      return true;
    }).toList();

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
        title: const Text('🧸 Kids Mode Setup'),
        actions: [
          TextButton.icon(
            onPressed: () {
              if (_hasPinSet) {
                ParentPinDialog.ensurePinAndRun(
                  context: context,
                  actionDescription: 'change your Parent PIN',
                  requireVerificationIfAlreadySet: true,
                  onSuccess: () {
                    ParentPinDialog.showChangePin(
                      context: context,
                      onPinUpdated: () {
                        setState(() => _hasPinSet = true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Parent PIN updated!'),
                            backgroundColor: AppTheme.mint,
                          ),
                        );
                      },
                    );
                  },
                );
              } else {
                ParentPinDialog.showChangePin(
                  context: context,
                  onPinUpdated: () {
                    setState(() => _hasPinSet = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Parent PIN created!'),
                        backgroundColor: AppTheme.mint,
                      ),
                    );
                  },
                );
              }
            },
            icon: const Icon(Icons.pin_outlined, color: AppTheme.cyan, size: 18),
            label: Text(
              _hasPinSet ? 'Change PIN' : 'Set PIN',
              style: const TextStyle(color: AppTheme.cyan, fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
          : Column(
              children: [
                // Top Configuration Card: Session Timer + Allow-List Policy Explanation
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.cardBorder(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'KIDS SESSION TIME LIMIT',
                            style: TextStyle(
                              color: AppTheme.textMuted(context),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            '$_kidsLimitMinutes mins',
                            style: const TextStyle(
                              color: AppTheme.cyan,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _presetLimits.map((mins) {
                          final isSelected = _kidsLimitMinutes == mins;
                          return GestureDetector(
                            onTap: () => setState(() => _kidsLimitMinutes = mins),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.cyan.withValues(alpha: 0.2) : AppTheme.background(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppTheme.cyan : AppTheme.cardBorder(context),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                '${mins}m',
                                style: TextStyle(
                                  color: isSelected ? AppTheme.cyan : AppTheme.textSecondary(context),
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: AppTheme.cyan.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined, color: AppTheme.cyan, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Select the ONLY apps your child can use below. All other apps on your phone will be automatically locked during Kids Mode.',
                                style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: 11.5,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Bar + Filter Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      TextField(
                        style: TextStyle(color: AppTheme.textPrimary(context)),
                        decoration: InputDecoration(
                          hintText: 'Search apps to allow for kids...',
                          hintStyle: TextStyle(color: AppTheme.textMuted(context)),
                          prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary(context)),
                          filled: true,
                          fillColor: AppTheme.surfaceCard(context),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: AppTheme.cardBorder(context)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: AppTheme.cardBorder(context)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppTheme.cyan),
                          ),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildFilterChip(0, 'All Apps', _installedApps.length, Icons.apps_rounded),
                          const SizedBox(width: 10),
                          _buildFilterChip(1, 'Allowed for Kids', _allowedPackages.length, Icons.check_circle_outline),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // App List
                Expanded(
                  child: filteredApps.isEmpty
                      ? Center(
                          child: Text(
                            'No matching apps found.',
                            style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 14),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          itemCount: filteredApps.length,
                          itemBuilder: (context, index) {
                            final app = filteredApps[index];
                            final pkg = app['packageName'] ?? '';
                            final name = app['appName'] ?? pkg;
                            final isAllowed = _allowedPackages.contains(pkg);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: isAllowed
                                    ? AppTheme.cyan.withValues(alpha: 0.08)
                                    : AppTheme.surfaceCard(context),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isAllowed ? AppTheme.cyan : AppTheme.cardBorder(context),
                                  width: isAllowed ? 1.5 : 1,
                                ),
                              ),
                              child: CheckboxListTile(
                                value: isAllowed,
                                activeColor: AppTheme.cyan,
                                checkColor: Colors.black,
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppTheme.textPrimary(context),
                                          fontWeight: isAllowed ? FontWeight.w700 : FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isAllowed
                                            ? AppTheme.cyan.withValues(alpha: 0.18)
                                            : AppTheme.glitchCoral.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isAllowed ? 'ALLOWED' : 'BLOCKED',
                                        style: TextStyle(
                                          color: isAllowed ? AppTheme.cyan : AppTheme.glitchCoral,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  pkg,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: AppTheme.textMuted(context), fontSize: 11.5),
                                ),
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _allowedPackages.add(pkg);
                                    } else {
                                      _allowedPackages.remove(pkg);
                                    }
                                  });
                                },
                              ),
                            );
                          },
                        ),
                ),

                // Bottom Save Button
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard(context),
                    border: Border(top: BorderSide(color: AppTheme.cardBorder(context))),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cyan,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: Text(
                        'Save Kids Setup (${_allowedPackages.length} Allowed • ${_kidsLimitMinutes}m)',
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

