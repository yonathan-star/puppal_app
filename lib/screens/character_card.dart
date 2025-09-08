import 'package:flutter/material.dart';
import 'package:my_new_app/screens/theme.dart';
import 'package:my_new_app/shared/styled_text.dart';
import 'package:my_new_app/model/pet_profile.dart';
import 'package:my_new_app/services/profile_storage.dart';
import 'package:my_new_app/screens/profile_edit_sheet.dart';

class CharacterCard extends StatelessWidget {
  const CharacterCard(this.profile, {super.key, this.onSaved});
  final PetProfile profile;
  final VoidCallback? onSaved;

  @override
  Widget build(BuildContext context) {
    final title = profile.name?.isNotEmpty == true
        ? profile.name!
        : '${profile.type.toUpperCase()} • ${profile.uidHex}';
    final subtitle = [
      if (profile.foodType != null) profile.foodType,
      if (profile.gramsPerDay != null) '${profile.gramsPerDay} g/day',
    ].whereType<String>().join(' • ');

    return Padding(
      padding: const EdgeInsets.only(right: 16.0), // Space between cards
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.secondaryBright,
          borderRadius: BorderRadius.circular(20),
        ),
        height: 140,
        width: 220,
        child: Column(
          children: [
            const SizedBox(height: 8),
            StyledText(title),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(subtitle),
            ],
            Expanded(child: Container()),
            IconButton(
              onPressed: () async {
                final updated = await showModalBottomSheet<PetProfile>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: ProfileEditSheet(profile: profile),
                  ),
                );
                if (updated != null) {
                  await ProfileStorage.upsert(updated);
                  onSaved?.call();
                }
              },
              icon: const Icon(Icons.edit),
            ),
          ],
        ),
      ),
    );
  }
}
