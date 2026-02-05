import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:autodentifyr/core/theme/app_palette.dart';
import 'package:autodentifyr/presentation/bloc/auth/auth_bloc.dart';
import 'package:autodentifyr/presentation/screens/camera_inference_screen.dart';
import 'package:autodentifyr/presentation/screens/single_image_screen.dart';

/// Home screen that presents mode selection after login
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AutoDentifyr',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () =>
                context.read<AuthBloc>().add(AuthLogoutRequested()),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppPalette.appBlue, AppPalette.blackColor],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                /* const Icon(
                  Icons.car_repair_rounded,
                  color: AppPallete.whiteColor,
                  size: 80,
                ), */
                Image.asset('assets/app_icon.png', width: 100, height: 100),
                const SizedBox(height: 16),
                Text(
                  'Choose Detection Mode',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppPalette.whiteColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 48),

                // Live Camera Mode
                _ModeCard(
                  icon: Icons.videocam,
                  title: 'Live Camera',
                  description: 'Real-time damage detection using your camera',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const CameraInferenceScreen(),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Upload Image Mode
                _ModeCard(
                  icon: Icons.photo_library,
                  title: 'Upload Image',
                  description: 'Analyze damage by uploading an image',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SingleImageScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppPalette.whiteColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppPalette.appGreen.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 64, color: AppPalette.appGreen),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppPalette.whiteColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppPalette.whiteColor.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
