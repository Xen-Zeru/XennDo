import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xenndo/core/theme/app_spacing.dart';
import 'package:xenndo/features/settings/application/settings_providers.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final info = ref.watch(appPackageInfoProvider);
    final version = info.when(
      data: (value) => value.buildNumber.isEmpty
          ? value.version
          : '${value.version} · Build ${value.buildNumber}',
      loading: () => 'Loading…',
      error: (_, _) => 'Unavailable',
    );
    return Scaffold(
      key: const ValueKey('about-screen'),
      appBar: AppBar(title: const Text('About XennDo')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              key: const ValueKey('about-content'),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                16,
                AppSpacing.pageHorizontal,
                32,
              ),
              children: [
                Semantics(
                  header: true,
                  child: Text('XennDo', style: theme.textTheme.headlineMedium),
                ),
                const SizedBox(height: 8),
                Text(
                  'Plan your day. Get it done.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'XennDo is a personal to-do app that helps you organize tasks, manage deadlines, and focus on what matters. Whether you’re planning schoolwork, work projects, or everyday activities, XennDo keeps your plans in one place.',
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 24),
                const _AboutSection(
                  title: 'Plan with purpose',
                  body: 'Organize tasks into lists, set priorities and reminders, and break larger tasks into smaller steps.',
                ),
                const _AboutSection(
                  title: 'Focus on what matters',
                  body: 'Choose your My Top 3 tasks each day and track your progress as you complete them.',
                ),
                const _AboutSection(
                  title: 'Available offline',
                  body: 'Manage your tasks without an internet connection or account.',
                ),
                const _AboutSection(
                  title: 'Your data, your control',
                  body: 'Tasks are stored locally on your device. Export a backup to keep a copy or restore it when moving to another device.',
                ),
                Card(
                  semanticContainer: false,
                  child: Column(
                    children: [
                      _DetailRow(label: 'Version', value: version),
                      if (info.hasError)
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(appPackageInfoProvider),
                          child: const Text('Retry version'),
                        ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      const _DetailRow(
                        label: 'Developed by',
                        value: 'Xenn Jan',
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        key: const ValueKey('about-licenses'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        title: const Text('Open-source licenses'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => showLicensePage(
                          context: context,
                          applicationName: 'XennDo',
                          applicationVersion: info.value?.version,
                        ),
                      ),
                    ],
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

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final heading = Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
          final content = Text(value, style: theme.textTheme.bodyMedium);
          if (constraints.maxWidth < 320 ||
              MediaQuery.textScalerOf(context).scale(14) > 19) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: 4), content],
            );
          }
          return Row(
            children: [
              Expanded(child: heading),
              const SizedBox(width: 16),
              Flexible(child: content),
            ],
          );
        },
      ),
    );
  }
}
