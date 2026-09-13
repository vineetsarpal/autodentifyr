import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:autodentifyr/core/theme/app_palette.dart';
import 'package:autodentifyr/presentation/bloc/auth/auth_bloc.dart';
import 'package:autodentifyr/presentation/screens/camera_inference_screen.dart';
import 'package:autodentifyr/presentation/screens/single_image_screen.dart';
import 'package:autodentifyr/presentation/controllers/assessment_workflow_composition.dart';

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
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /* const Icon(
                  Icons.car_repair_rounded,
                  color: AppPallete.whiteColor,
                  size: 80,
                ), */
                      Image.asset(
                        'assets/app_icon.png',
                        width: 100,
                        height: 100,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'What would you like to do?',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppPalette.whiteColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 40),
                      const _SectionLabel('PROFESSIONAL WORKFLOW'),
                      const SizedBox(height: 12),
                      _ModeCard(
                        icon: Icons.assignment_outlined,
                        title: 'Assessment Workspace',
                        description:
                            'Create and manage documented vehicle intake assessments',
                        supportingText: 'Saved • Reviewable • Reportable',
                        isPrimary: true,
                        onTap: () async {
                          final screen = await openAssessmentWorkflowScreen();
                          if (!context.mounted) return;
                          await Navigator.of(
                            context,
                          ).push(MaterialPageRoute(builder: (_) => screen));
                        },
                      ),

                      const SizedBox(height: 32),
                      const _SectionLabel('QUICK DETECTION'),
                      const SizedBox(height: 12),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _ModeCard(
                                icon: Icons.photo_library_outlined,
                                title: 'Analyze Photo',
                                description:
                                    'Check one image for visible damage',
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SingleImageScreen(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _ModeCard(
                                icon: Icons.videocam_outlined,
                                title: 'Live Detection',
                                showBetaTag: true,
                                description:
                                    'Preview damage detection in real time',
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const CameraInferenceScreen(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        label,
        style: TextStyle(
          color: AppPalette.whiteColor.withValues(alpha: 0.72),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
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
    this.supportingText,
    this.isPrimary = false,
    this.showBetaTag = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final String? supportingText;
  final bool isPrimary;
  final bool showBetaTag;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isPrimary ? 24 : 16),
        decoration: BoxDecoration(
          color: isPrimary
              ? AppPalette.appGreen.withValues(alpha: 0.18)
              : AppPalette.whiteColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppPalette.appGreen.withValues(
              alpha: isPrimary ? 0.75 : 0.28,
            ),
            width: 2,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: isPrimary ? 56 : 40,
                  color: AppPalette.appGreen,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppPalette.whiteColor,
                    fontSize: 19,
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
                if (supportingText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    supportingText!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isPrimary
                          ? AppPalette.appGreen
                          : AppPalette.whiteColor.withValues(alpha: 0.58),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            if (showBetaTag)
              Positioned(
                top: -12,
                right: -12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.appGreen,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Text(
                    'BETA',
                    style: TextStyle(
                      color: AppPalette.appBlue,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
