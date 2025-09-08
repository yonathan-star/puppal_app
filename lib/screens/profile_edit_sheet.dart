import 'package:flutter/material.dart';
import 'package:my_new_app/model/pet_profile.dart';
import 'package:my_new_app/services/food_database.dart';
import 'package:my_new_app/services/food_estimator.dart';
import 'package:my_new_app/services/ai_density_service.dart';

class ProfileEditSheet extends StatefulWidget {
  const ProfileEditSheet({super.key, required this.profile});

  final PetProfile profile;

  @override
  State<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<ProfileEditSheet> {
  late TextEditingController _foodController;
  late TextEditingController _gramsController;
  late TextEditingController _brandSearchController;

  List<FoodItem> _results = [];
  String? _selectedBrand;
  int? _selectedDensity;

  List<TimeWindow> _windows = [];
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    _foodController = TextEditingController(
      text: widget.profile.foodType ?? '',
    );
    _gramsController = TextEditingController(
      text: widget.profile.gramsPerDay?.toString() ?? '',
    );
    _brandSearchController = TextEditingController(
      text: widget.profile.foodBrand ?? '',
    );
    _selectedBrand = widget.profile.foodBrand;
    _selectedDensity = widget.profile.foodDensityGramsPerCup;
    _windows = List.of(widget.profile.allowedWindows ?? const []);
    _loadAll();
  }

  Future<void> _loadAll() async {
    final all = await FoodDatabase.load();
    if (!mounted) return;
    setState(() {
      _results = all;
    });
  }

  @override
  void dispose() {
    _foodController.dispose();
    _gramsController.dispose();
    _brandSearchController.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final list = await FoodDatabase.search(q);
    if (!mounted) return;
    setState(() {
      _results = list;
    });
  }

  Future<void> _addWindow() async {
    final picked = await showTimeRangePicker(context);
    if (picked == null) return;
    setState(() {
      _windows.add(picked);
    });
  }

  Future<void> _estimateDensity() async {
    final query = _brandSearchController.text.trim();
    if (query.isEmpty) return;
    final estimate = await FoodEstimator.estimateDensityForBrand(query);
    if (!mounted) return;
    setState(() {
      _selectedBrand = query;
      _selectedDensity = estimate;
    });
  }

  Future<void> _aiLookupOnline() async {
    final query = _brandSearchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _aiLoading = true;
    });
    try {
      // TODO: set your worker URL here or inject via constructor/settings
      final svc = AiDensityService(
        baseUrl: 'https://puppal-ai-worker.yonathangal12345.workers.dev',
      );
      final res = await svc.estimateDensity(query);
      if (!mounted) return;
      if (res != null) {
        setState(() {
          _selectedBrand = query;
          _selectedDensity = res;
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('AI lookup failed')));
      }
    } finally {
      if (mounted)
        setState(() {
          _aiLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit ${widget.profile.type.toUpperCase()} • ${widget.profile.uidHex}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _foodController,
              decoration: const InputDecoration(
                labelText: 'Food Type (optional)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _gramsController,
              decoration: const InputDecoration(labelText: 'Grams per day'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _brandSearchController,
              decoration: const InputDecoration(
                labelText: 'Search brand (database)',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _search,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _estimateDensity,
                    child: const Text('Estimate density for this brand'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _aiLoading ? null : _aiLookupOnline,
                    icon: _aiLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_outlined),
                    label: const Text('AI lookup (online)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final item = _results[i];
                  final selected = _selectedBrand == item.brand;
                  return ListTile(
                    title: Text(item.brand),
                    subtitle: Text('${item.densityGramsPerCup} g/cup'),
                    trailing: selected ? const Icon(Icons.check) : null,
                    onTap: () {
                      setState(() {
                        _selectedBrand = item.brand;
                        _selectedDensity = item.densityGramsPerCup;
                        if (_brandSearchController.text != item.brand) {
                          _brandSearchController.text = item.brand;
                        }
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            if (_selectedDensity != null)
              Text('Selected density: $_selectedDensity g/cup'),
            const SizedBox(height: 16),
            Text(
              'Allowed entries (daily time windows)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._windows.asMap().entries.map((e) {
              final idx = e.key;
              final w = e.value;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_formatWindow(w)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    setState(() {
                      _windows.removeAt(idx);
                    });
                  },
                ),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addWindow,
                icon: const Icon(Icons.add),
                label: const Text('Add time window'),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final grams = int.tryParse(_gramsController.text.trim());
                Navigator.of(context).pop(
                  PetProfile(
                    uidHex: widget.profile.uidHex,
                    type: widget.profile.type,
                    name: widget.profile.name,
                    foodType: _foodController.text.trim().isEmpty
                        ? null
                        : _foodController.text.trim(),
                    gramsPerDay: grams,
                    foodBrand: _selectedBrand,
                    foodDensityGramsPerCup: _selectedDensity,
                    allowedWindows: _windows,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatWindow(TimeWindow w) {
    String f(int m) =>
        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
    return '${f(w.startMinutes)} - ${f(w.endMinutes)}';
  }

  Future<TimeWindow?> showTimeRangePicker(BuildContext context) async {
    TimeOfDay start = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 18, minute: 0);

    TimeOfDay? pickedStart = await showTimePicker(
      context: context,
      initialTime: start,
    );
    if (pickedStart == null) return null;
    TimeOfDay? pickedEnd = await showTimePicker(
      context: context,
      initialTime: end,
    );
    if (pickedEnd == null) return null;

    int s = pickedStart.hour * 60 + pickedStart.minute;
    int e = pickedEnd.hour * 60 + pickedEnd.minute;
    if (e == s) return null; // ignore empty range
    return TimeWindow(startMinutes: s, endMinutes: e);
  }
}
