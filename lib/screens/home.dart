import 'package:flutter/material.dart';
import 'package:my_new_app/screens/character_card.dart';
import 'package:my_new_app/screens/theme.dart';
import 'package:my_new_app/shared/styled_text.dart';
import 'package:my_new_app/screens/ble_manager.dart';
import 'package:my_new_app/model/pet_profile.dart';
import 'package:my_new_app/services/profile_storage.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<PetProfile> _profiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final list = await ProfileStorage.load();
    setState(() {
      _profiles = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const StyledText('Home Screen')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const StyledTitle('Your Pets'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.secondaryColor.withBlue(100), // dark blue
              borderRadius: BorderRadius.circular(20),
            ),
            height: 250,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _profiles.isEmpty
                ? const Center(child: Text('No profiles yet'))
                : Column(
                    children: [
                      Expanded(child: Container()),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _profiles.length,
                          itemBuilder: (_, index) {
                            final p = _profiles[index];
                            return CharacterCard(p, onSaved: _loadProfiles);
                          },
                        ),
                      ),
                      Expanded(child: Container()),
                      // You can add more widgets here or leave the rest empty
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) => const BleManagerScreen(),
                        ),
                      )
                      .then((_) => _loadProfiles());
                },
                icon: const Icon(Icons.bluetooth),
                label: const Text('Open PupPal Bluetooth Manager'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
