import 'package:flutter/material.dart';
import 'package:my_new_app/model/pet_profile.dart';
import 'package:my_new_app/services/food_database.dart';
import 'package:my_new_app/services/ai_density_service.dart';
import 'package:my_new_app/services/arduino_service.dart';
import 'package:my_new_app/ai/local_feeding_ai.dart';
import 'package:my_new_app/services/breed_lookup_service.dart';

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
  // Add controllers for weight, breed, age, neuter, activity, BCS
  late TextEditingController _weightController;
  String _species = 'dog';
  String _breed = 'Mixed/Unknown';
  String _ageStage = 'adult';
  bool _neutered = true;
  int _activity = 3;
  int _bcs = 5;

  List<FoodItem> _results = [];
  String? _selectedBrand;
  int? _selectedDensity;

  List<TimeWindow> _windows = [];
  bool _aiLoading = false;
  String? _confirmedBreed;
  bool _breedLoading = false;

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
    _weightController = TextEditingController();
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

  Future<void> _aiLookupOnline() async {
    final query = _brandSearchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _aiLoading = true;
    });
    try {
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

        // Show AI confidence feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ AI found: ${res}g/cup'),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('❌ AI lookup failed')));
      }
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final inputTextStyle = textTheme.bodyLarge?.copyWith(fontSize: 18);
    final labelStyle = textTheme.labelLarge?.copyWith(fontSize: 16);
    final buttonStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      textStyle: textTheme.labelLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      minimumSize: const Size.fromHeight(48),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit ${widget.profile.type.toUpperCase()} • ${widget.profile.uidHex}',
              style: textTheme.headlineSmall?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _foodController,
              style: inputTextStyle,
              decoration: InputDecoration(
                labelText: 'Food Type (optional)',
                labelStyle: labelStyle,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _gramsController,
              style: inputTextStyle,
              decoration: InputDecoration(
                labelText: 'Grams per day',
                labelStyle: labelStyle,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _weightController,
              style: inputTextStyle,
              decoration: InputDecoration(
                labelText: 'Weight (kg)',
                labelStyle: labelStyle,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _species,
              items: const [
                DropdownMenuItem(value: 'dog', child: Text('Dog')),
                DropdownMenuItem(value: 'cat', child: Text('Cat')),
              ],
              onChanged: (v) => setState(() => _species = v!),
              decoration: InputDecoration(
                labelText: 'Species',
                labelStyle: labelStyle,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                border: const OutlineInputBorder(),
              ),
              style: inputTextStyle,
            ),
            const SizedBox(height: 12),
            TextField(
              style: inputTextStyle,
              decoration: InputDecoration(
                labelText: 'Breed',
                labelStyle: labelStyle,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _breed = v),
              onSubmitted: (v) async {
                final localList = _species == 'dog'
                    ? LocalFeedingAI.dogBreeds
                    : LocalFeedingAI.catBreeds;
                if (!localList.contains(v)) {
                  setState(() => _breedLoading = true);
                  final match = _species == 'dog'
                      ? await BreedLookupService.lookupDogBreed(v)
                      : await BreedLookupService.lookupCatBreed(v);
                  setState(() => _breedLoading = false);
                  if (match != null && match.similarity > 0.6) {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text(
                          'Breed Match Found',
                          textAlign: TextAlign.center,
                        ),
                        content: Text(
                          'Did you mean "${match.name}" (group: ${match.group})?',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge?.copyWith(fontSize: 18),
                        ),
                        actionsAlignment: MainAxisAlignment.center,
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('No'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Yes'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      setState(() {
                        _breed = match.name;
                        _confirmedBreed = match.name;
                      });
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No close breed match found online. Using Mixed/Unknown.',
                          textAlign: TextAlign.center,
                        ),
                        duration: Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating,
                        margin: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    );
                    setState(() {
                      _confirmedBreed = null;
                    });
                  }
                } else {
                  setState(() {
                    _confirmedBreed = v;
                  });
                }
              },
            ),
            if (_breedLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: LinearProgressIndicator(minHeight: 4),
              ),
            if (_confirmedBreed != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Using breed: $_confirmedBreed',
                  style: textTheme.bodyMedium?.copyWith(fontSize: 16),
                ),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _ageStage,
              items: const [
                DropdownMenuItem(
                  value: 'puppyKitten',
                  child: Text('Puppy/Kitten'),
                ),
                DropdownMenuItem(value: 'adult', child: Text('Adult')),
                DropdownMenuItem(value: 'senior', child: Text('Senior')),
              ],
              onChanged: (v) => setState(() => _ageStage = v!),
              decoration: InputDecoration(
                labelText: 'Age',
                labelStyle: labelStyle,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                border: const OutlineInputBorder(),
              ),
              style: inputTextStyle,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Neutered', style: labelStyle),
                const SizedBox(width: 8),
                Switch(
                  value: _neutered,
                  onChanged: (v) => setState(() => _neutered = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Activity', style: labelStyle),
                Expanded(
                  child: Slider(
                    value: _activity.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: _activity.toString(),
                    onChanged: (v) => setState(() => _activity = v.round()),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text('BCS', style: labelStyle),
                Expanded(
                  child: Slider(
                    value: _bcs.toDouble(),
                    min: 1,
                    max: 9,
                    divisions: 8,
                    label: _bcs.toString(),
                    onChanged: (v) => setState(() => _bcs = v.round()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.calculate),
              label: const Text('Estimate Grams (AI)'),
              style: buttonStyle,
              onPressed: () {
                final weight =
                    double.tryParse(_weightController.text.trim()) ?? 10.0;
                final foodProfile = FoodProfile(
                  kcalPerGram: null,
                  kcalPerCup: null,
                  gramsPerCup: _selectedDensity?.toDouble(),
                );
                final input = FeedingInput(
                  species: _species == 'dog' ? Species.dog : Species.cat,
                  weightKg: weight,
                  breedKey:
                      _confirmedBreed ??
                      (_breed.isEmpty ? 'Mixed/Unknown' : _breed),
                  ageStage: _ageStage == 'puppyKitten'
                      ? AgeStage.puppyKitten
                      : _ageStage == 'senior'
                      ? AgeStage.senior
                      : AgeStage.adult,
                  neutered: _neutered,
                  activityLevel: _activity,
                  bcs: _bcs,
                  food: foodProfile,
                );
                final result = LocalFeedingAI.estimate(input);
                setState(() {
                  _gramsController.text = result.gramsPerDay.round().toString();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'AI estimate: ${result.gramsPerDay.round()} grams/day',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(fontSize: 18),
                    ),
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            // --- Food brand selection area with borders ---
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[400]!, width: 1),
                  bottom: BorderSide(color: Colors.grey[400]!, width: 1),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _brandSearchController,
                    style: inputTextStyle,
                    decoration: InputDecoration(
                      labelText: 'Search brand (database)',
                      labelStyle: labelStyle,
                      prefixIcon: const Icon(Icons.search),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: _search,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 150,
                    child: ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (_, i) {
                        final item = _results[i];
                        final selected = _selectedBrand == item.brand;
                        return ListTile(
                          title: Text(
                            item.brand,
                            style: textTheme.bodyLarge?.copyWith(fontSize: 18),
                          ),
                          subtitle: Text(
                            '${item.densityGramsPerCup} g/cup',
                            style: textTheme.bodyMedium?.copyWith(fontSize: 16),
                          ),
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 0,
                          ),
                          dense: true,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedDensity != null)
                    Text(
                      'Selected density: $_selectedDensity g/cup',
                      style: textTheme.bodyMedium?.copyWith(fontSize: 16),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
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
                style: buttonStyle,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Allowed entries (daily time windows)',
              style: textTheme.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ..._windows.asMap().entries.map((e) {
              final idx = e.key;
              final w = e.value;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 0,
                ),
                title: Text(
                  _formatWindow(w),
                  style: textTheme.bodyLarge?.copyWith(fontSize: 18),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    setState(() {
                      _windows.removeAt(idx);
                    });
                  },
                ),
                dense: true,
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addWindow,
                icon: const Icon(Icons.add),
                label: const Text('Add time window'),
                style: TextButton.styleFrom(
                  textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final grams = int.tryParse(_gramsController.text.trim());
                final updatedProfile = PetProfile(
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
                );
                if (grams != null && _selectedDensity != null) {
                  try {
                    await ArduinoService.setMetadata(
                      widget.profile.uidHex,
                      grams,
                      _selectedDensity!,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '✅ Arduino updated successfully',
                            textAlign: TextAlign.center,
                          ),
                          duration: Duration(seconds: 3),
                          behavior: SnackBarBehavior.floating,
                          margin: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '⚠️ Arduino sync failed: $e',
                            textAlign: TextAlign.center,
                          ),
                          duration: const Duration(seconds: 3),
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      );
                    }
                  }
                }
                if (mounted) {
                  Navigator.of(context).pop(updatedProfile);
                }
              },
              icon: const Icon(Icons.sync),
              label: const Text('Save & Sync to Arduino'),
              style: buttonStyle,
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
