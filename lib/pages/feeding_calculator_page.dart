import 'package:flutter/material.dart';
import '../ai/local_feeding_ai.dart';

/// Call this from anywhere to open the calculator and get grams/day.
/// Example:
///   final grams = await showFeedingCalculator(context);
Future<double?> showFeedingCalculator(BuildContext context) async {
  return Navigator.push<double>(
    context,
    MaterialPageRoute(builder: (_) => const FeedingCalculatorPage()),
  );
}

class FeedingCalculatorPage extends StatefulWidget {
  const FeedingCalculatorPage({super.key});
  @override
  State<FeedingCalculatorPage> createState() => _FeedingCalculatorPageState();
}

class _FeedingCalculatorPageState extends State<FeedingCalculatorPage> {
  Species _species = Species.dog;
  String _breed = "Mixed/Unknown";
  bool _kgUnits = true;
  double _weight = 10;
  AgeStage _age = AgeStage.adult;
  bool _neutered = true;
  int _activity = 3;
  int _bcs = 5;

  final kcalPerGramCtl = TextEditingController();
  final kcalPerCupCtl = TextEditingController();
  final gramsPerCupCtl = TextEditingController();

  FeedingResult? _result;

  List<String> get _breedList => _species == Species.dog
      ? LocalFeedingAI.dogBreeds
      : LocalFeedingAI.catBreeds;

  double get _weightKg => _kgUnits ? _weight : _weight * 0.45359237;

  void _compute() {
    final food = FoodProfile(
      kcalPerGram: double.tryParse(kcalPerGramCtl.text),
      kcalPerCup: double.tryParse(kcalPerCupCtl.text),
      gramsPerCup: double.tryParse(gramsPerCupCtl.text),
    );
    final input = FeedingInput(
      species: _species,
      weightKg: _weightKg.clamp(0.5, 100.0),
      breedKey: _breed,
      ageStage: _age,
      neutered: _neutered,
      activityLevel: _activity,
      bcs: _bcs.clamp(1, 9),
      food: food,
    );
    setState(() => _result = LocalFeedingAI.estimate(input));
  }

  void _applyAndClose() {
    if (_result == null) return;
    Navigator.pop(context, _result!.gramsPerDay);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PupPal • Feeding Estimator (Local)"),
        actions: [
          if (_result != null)
            TextButton(
              onPressed: _applyAndClose,
              child: const Text(
                "USE THIS",
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              DropdownButton<Species>(
                value: _species,
                items: const [
                  DropdownMenuItem(value: Species.dog, child: Text("Dog")),
                  DropdownMenuItem(value: Species.cat, child: Text("Cat")),
                ],
                onChanged: (v) => setState(() {
                  _species = v!;
                  _breed = "Mixed/Unknown";
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BreedAutocomplete(
                  breeds: _breedList,
                  value: _breed,
                  onChanged: (v) => setState(() => _breed = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _weight.toStringAsFixed(1),
                  decoration: InputDecoration(
                    labelText: "Weight (${_kgUnits ? "kg" : "lb"})",
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (v) {
                    final x = double.tryParse(v);
                    if (x != null && x > 0) setState(() => _weight = x);
                  },
                ),
              ),
              const SizedBox(width: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("kg"),
                value: _kgUnits,
                onChanged: (v) => setState(() => _kgUnits = v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text("Puppy/Kitten"),
                selected: _age == AgeStage.puppyKitten,
                onSelected: (_) => setState(() => _age = AgeStage.puppyKitten),
              ),
              ChoiceChip(
                label: const Text("Adult"),
                selected: _age == AgeStage.adult,
                onSelected: (_) => setState(() => _age = AgeStage.adult),
              ),
              ChoiceChip(
                label: const Text("Senior"),
                selected: _age == AgeStage.senior,
                onSelected: (_) => setState(() => _age = AgeStage.senior),
              ),
              FilterChip(
                label: const Text("Neutered/Spayed"),
                selected: _neutered,
                onSelected: (v) => setState(() => _neutered = v),
              ),
            ],
          ),
          Row(
            children: [
              const Text("Activity"),
              Expanded(
                child: Slider(
                  value: _activity.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: "$_activity",
                  onChanged: (v) =>
                      setState(() => _activity = v.round().clamp(1, 5)),
                ),
              ),
              const SizedBox(width: 8),
              const Text("BCS"),
              Expanded(
                child: Slider(
                  value: _bcs.toDouble(),
                  min: 1,
                  max: 9,
                  divisions: 8,
                  label: "$_bcs",
                  onChanged: (v) =>
                      setState(() => _bcs = v.round().clamp(1, 9)),
                ),
              ),
            ],
          ),
          const Divider(),
          const Text("Food Energy (optional)"),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: kcalPerGramCtl,
                  decoration: const InputDecoration(
                    labelText: "kcal per gram (e.g., 3.6)",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: kcalPerCupCtl,
                  decoration: const InputDecoration(
                    labelText: "kcal per cup (e.g., 360)",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: gramsPerCupCtl,
                  decoration: const InputDecoration(
                    labelText: "grams per cup (e.g., 100)",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _compute,
            icon: const Icon(Icons.calculate),
            label: const Text("Estimate Daily Food"),
          ),
          const SizedBox(height: 12),
          if (_result != null) _ResultCard(result: _result!),
          const SizedBox(height: 40),
          Text(
            "This on-device estimator uses standard veterinary equations as general guidance.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final FeedingResult result;
  const _ResultCard({required this.result});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Estimated Daily Intake",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text("Energy: ${result.merKcal.toStringAsFixed(0)} kcal/day"),
            Text(
              "Amount: ${result.gramsPerDay.toStringAsFixed(0)} g/day"
              "${result.cupsPerDay != null ? "  •  ${result.cupsPerDay!.toStringAsFixed(2)} cups/day" : ""}",
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text("How this was calculated"),
              children: result.explanation
                  .map((e) => ListTile(title: Text(e)))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Text(
              "Tip: Split into 2 meals → ${(result.gramsPerDay / 2).toStringAsFixed(0)} g per meal.",
            ),
          ],
        ),
      ),
    );
  }
}

class _BreedAutocomplete extends StatelessWidget {
  final List<String> breeds;
  final String value;
  final ValueChanged<String> onChanged;
  const _BreedAutocomplete({
    required this.breeds,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: value),
      optionsBuilder: (t) {
        final q = t.text.toLowerCase().trim();
        if (q.isEmpty) return breeds;
        return breeds.where((b) => b.toLowerCase().contains(q));
      },
      onSelected: onChanged,
      fieldViewBuilder: (ctx, ctl, focus, onSubmit) {
        ctl.text = value;
        return TextField(
          controller: ctl,
          focusNode: focus,
          decoration: const InputDecoration(
            labelText: "Breed",
            border: OutlineInputBorder(),
          ),
          onChanged: onChanged,
        );
      },
    );
  }
}
