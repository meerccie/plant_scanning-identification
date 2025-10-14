import 'package:flutter/material.dart';
import 'package:my_plant/components/app_colors.dart';
import 'package:my_plant/components/input_field.dart';
import 'package:my_plant/providers/auth_provider.dart';

class ProfileEditView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController usernameController;
  final TextEditingController fullNameController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final AuthProvider authProvider;

  const ProfileEditView({
    super.key,
    required this.formKey,
    required this.usernameController,
    required this.fullNameController,
    required this.phoneController,
    required this.addressController,
    required this.authProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          Card(
            color: AppColors.secondaryColor, // Consistent with section tile
            child: SwitchListTile(
              title: const Text('Private Profile',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                  'If enabled, others cannot view your profile details.',
                  style: TextStyle(color: Colors.white70)),
              value: authProvider.isProfilePrivate,
              onChanged: (value) => authProvider.setProfilePrivacy(value),
              secondary: const Icon(Icons.lock_outline, color: Colors.white),
              activeColor: AppColors.primaryColor,
            ),
          ),
          const Divider(height: 40, color: Colors.white24),
          CustomInputField(
              controller: usernameController,
              label: 'Username',
              prefixIcon: const Icon(Icons.person_outline)),
          CustomInputField(
              controller: fullNameController,
              label: 'Full Name',
              prefixIcon: const Icon(Icons.badge_outlined)),
          CustomInputField(
              controller: phoneController,
              label: 'Phone Number',
              keyboardType: TextInputType.phone,
              prefixIcon: const Icon(Icons.phone_outlined)),
          CustomInputField(
              controller: addressController,
              label: 'Address',
              maxLines: 3,
              prefixIcon: const Icon(Icons.location_on_outlined)),
        ],
      ),
    );
  }
}

