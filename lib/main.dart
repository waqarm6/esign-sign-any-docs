import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as image_lib;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:screen_security/screen_security.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'onboarding_screen.dart';
import 'startup_paywall_screen.dart';
import 'services/native_document_scanner.dart';
import 'services/signature_store.dart';
import 'models/document_record.dart';
import 'services/document_store.dart';
import 'services/subscription_service.dart';

TextStyle _annotationTextStyle(String fontFamily, double fontSize, Color color,
        {FontWeight? fontWeight, double? letterSpacing}) =>
    GoogleFonts.getFont(
      fontFamily,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    ).copyWith(inherit: false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ESignDocProApp());
}

class ESignDocProApp extends StatefulWidget {
  const ESignDocProApp({super.key});

  @override
  State<ESignDocProApp> createState() => _ESignDocProAppState();
}

class _ESignDocProAppState extends State<ESignDocProApp> {
  late final Future<bool> _onboardingComplete;
  late final Future<bool> _activeSubscription;

  @override
  void initState() {
    super.initState();
    _onboardingComplete = SharedPreferences.getInstance().then(
      (prefs) => prefs.getBool(onboardingCompleteKey) ?? false,
    );
    _activeSubscription = SubscriptionService().hasActiveEntitlement();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enableScreenSecurity();
    });
  }

  Future<void> _enableScreenSecurity() async {
    // Allow visual QA in debug builds; shipped builds still block capture.
    if (!kReleaseMode) return;
    try {
      await ScreenSecurity().enable();
    } catch (_) {
      // Keep the app usable if a platform build does not support screen locking.
    }
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF17212B);
    const accent = Color(0xFF0E7490);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'eSign : Sign Any Docs',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.light,
          surface: const Color(0xFFF8FAFB),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFB),
        fontFamily: 'sans',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: ink,
            letterSpacing: -1.0,
          ),
          headlineSmall: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: ink,
            letterSpacing: -0.4,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: Color(0xFF62707B),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      home: FutureBuilder<bool>(
        future: _onboardingComplete,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.data!) {
            return FutureBuilder<bool>(
              future: _activeSubscription,
              builder: (context, entitlement) {
                if (!entitlement.hasData) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (entitlement.data!) return const HomeScreen();
                return Builder(
                  builder: (routeContext) => StartupPaywallScreen(
                    onContinue: () =>
                        Navigator.of(routeContext).pushReplacement(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    ),
                  ),
                );
              },
            );
          }
          return Builder(
            builder: (routeContext) => OnboardingScreen(
              onDone: () async {
                final active = await _activeSubscription;
                if (!routeContext.mounted) return;
                Navigator.of(routeContext).pushReplacement(
                  MaterialPageRoute(
                    builder: (paywallContext) => active
                        ? const HomeScreen()
                        : StartupPaywallScreen(
                            onContinue: () => Navigator.of(paywallContext)
                                .pushReplacement(MaterialPageRoute(
                              builder: (_) => const HomeScreen(),
                            )),
                          ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final documentStore = DocumentStore();
  late Future<List<DocumentRecord>> documents;
  List<DocumentRecord> lastDocuments = const <DocumentRecord>[];

  @override
  void initState() {
    super.initState();
    documents = documentStore.loadDocuments();
    DocumentStore.changes.addListener(_refreshDocuments);
  }

  @override
  void dispose() {
    DocumentStore.changes.removeListener(_refreshDocuments);
    super.dispose();
  }

  void _refreshDocuments() {
    if (!mounted) return;
    setState(() {
      lastDocuments = DocumentStore.currentDocuments;
      documents = Future.value(lastDocuments);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'eSign : Sign Any Docs',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () => _openSettings(context),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text('Good morning', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            'What would you like to do?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _PrimaryAction(
                  icon: Icons.document_scanner_outlined,
                  label: 'Scan document',
                  onTap: () => _openScanner(context, ScannerMode.scan),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PrimaryAction(
                  icon: Icons.upload_file_outlined,
                  label: 'Import file',
                  onTap: () => _openScanner(context, ScannerMode.importFile),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _SectionHeader(
            title: 'Your documents',
            action: 'See all',
            onTap: () => _openDocuments(context),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<DocumentRecord>>(
            future: documents,
            builder: (context, snapshot) {
              final items = snapshot.data ?? lastDocuments;
              if (snapshot.hasData) lastDocuments = items;
              final drafts = items
                  .where((item) => item.status == DocumentStatus.draft)
                  .length;
              final completed = items
                  .where((item) => item.status == DocumentStatus.completed)
                  .length;
              return Row(
                children: [
                  Expanded(
                    child: _CountCard(
                      label: 'Drafts',
                      count: '$drafts',
                      icon: Icons.edit_note_outlined,
                      onTap: () => _openDocuments(
                        context,
                        filter: DocumentStatus.draft,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CountCard(
                      label: 'Completed',
                      count: '$completed',
                      icon: Icons.check_circle_outline,
                      onTap: () => _openDocuments(
                        context,
                        filter: DocumentStatus.completed,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          _SectionHeader(
            title: 'Tools',
            action: 'View all',
            onTap: () => _openTools(context),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                _ToolRow(
                  icon: Icons.draw_outlined,
                  title: 'Create signature',
                  subtitle: 'Save a reusable signature',
                  onTap: () => _openSignature(context),
                ),
                const Divider(height: 1, indent: 64),
                _ToolRow(
                  icon: Icons.text_fields_outlined,
                  title: 'Saved fields',
                  subtitle: 'Initials, dates, and stamps',
                  onTap: () => _openTools(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Card(
            color: const Color(0xFFEAF5F5),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, color: Color(0xFF0E7490)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your documents are processed privately on your device.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF285E67),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) _openDocuments(context);
          if (index == 2) _openTools(context);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Documents',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Tools',
          ),
        ],
      ),
    );
  }

  Future<void> _openScanner(BuildContext context, ScannerMode mode) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ScannerFlow(mode: mode)));
    _refreshDocuments();
  }

  void _openSignature(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SignatureScreen()));
  }

  void _openDocuments(BuildContext context, {DocumentStatus? filter}) {
    Navigator.of(
      context,
    )
        .push(
          MaterialPageRoute(
            builder: (_) => DocumentLibraryScreen(initialFilter: filter),
          ),
        )
        .then((_) => _refreshDocuments());
  }

  void _openSettings(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _openTools(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ToolsScreen()));
  }
}

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Tools',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const _SettingsHeading('Saved tools'),
            Card(
              child: FutureBuilder<bool>(
                future: SignatureStore().hasSavedSignature(),
                builder: (context, snapshot) {
                  final hasSignature = snapshot.data ?? false;
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE5F4F5),
                      foregroundColor: Color(0xFF0E7490),
                      child: Icon(Icons.draw_outlined),
                    ),
                    title: const Text(
                      'Saved signature',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      hasSignature
                          ? 'Ready to use in any document'
                          : 'Create your reusable signature',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SignatureScreen(),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 22),
            const _SettingsHeading('Annotation styles'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.verified_outlined,
                      color: Color(0xFF0E7490),
                    ),
                    title: const Text('Stamp presets'),
                    subtitle: const Text('Approved, Paid, Review, Rejected'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showStampPresets(context),
                  ),
                  const Divider(height: 1, indent: 64),
                  ListTile(
                    leading: const Icon(
                      Icons.text_fields_outlined,
                      color: Color(0xFF0E7490),
                    ),
                    title: const Text('Font library'),
                    subtitle: const Text('Modern fonts for text and dates'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showFontLibrary(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Card(
              color: const Color(0xFFEAF5F5),
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(Icons.tune_outlined, color: Color(0xFF0E7490)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'All styles remain adjustable after placement. Open a document to add and edit them.',
                        style: TextStyle(color: Color(0xFF285E67)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  void _showStampPresets(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: const [
            Text(
              'Stamp presets',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 16),
            _PresetStampPreview(label: 'APPROVED', color: Color(0xFF0E7490)),
            _PresetStampPreview(label: 'PAID', color: Color(0xFF2E7D32)),
            _PresetStampPreview(label: 'REVIEW', color: Color(0xFFB26A00)),
            _PresetStampPreview(label: 'REJECTED', color: Color(0xFFB23A3A)),
          ],
        ),
      ),
    );
  }

  void _showFontLibrary(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            const Text(
              'Font library',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a font from the style panel after placing text or a date.',
              style: TextStyle(color: Color(0xFF62707B)),
            ),
            const SizedBox(height: 12),
            ..._annotationFontFamilies.map(
              (font) => ListTile(
                dense: true,
                title: Text(font, style: GoogleFonts.getFont(font)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetStampPreview extends StatelessWidget {
  final String label;
  final Color color;
  const _PresetStampPreview({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ),
      );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool followSystem = true;
  bool restoring = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Settings',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _openPremiumWall,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5F4F5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.workspace_premium_outlined,
                            color: Color(0xFF0E7490),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'eSign : Sign Any Docs Premium',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Weekly, monthly & yearly plans',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF62707B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: Color(0xFF9BA8AE)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const _SettingsHeading('Preferences'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      value: followSystem,
                      onChanged: (value) =>
                          setState(() => followSystem = value),
                      title: const Text('Use system appearance'),
                      subtitle:
                          const Text('Follow light and dark mode settings'),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      onTap: () => _showLanguage(context),
                      leading: const Icon(
                        Icons.language_outlined,
                        color: Color(0xFF50616B),
                      ),
                      title: const Text('Language'),
                      trailing: const Text(
                        'English',
                        style: TextStyle(color: Color(0xFF62707B)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const _SettingsHeading('Subscription'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      onTap: _manageSubscription,
                      leading: const Icon(
                        Icons.manage_accounts_outlined,
                        color: Color(0xFF50616B),
                      ),
                      title: const Text('Manage subscription'),
                      trailing: const Icon(
                        Icons.open_in_new,
                        size: 18,
                        color: Color(0xFF9BA8AE),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      onTap: _restorePurchases,
                      leading: const Icon(
                        Icons.restore_outlined,
                        color: Color(0xFF50616B),
                      ),
                      title: const Text('Restore purchases'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const _SettingsHeading('About'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (introContext) => OnboardingScreen(
                            onDone: () => Navigator.of(introContext).pop(),
                          ),
                        ),
                      ),
                      leading: const Icon(
                        Icons.auto_stories_outlined,
                        color: Color(0xFF50616B),
                      ),
                      title: const Text('View introduction'),
                      trailing: const Icon(Icons.chevron_right,
                          color: Color(0xFF9BA8AE)),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      onTap: () => _showPolicy(context, 'Privacy policy'),
                      leading: const Icon(
                        Icons.privacy_tip_outlined,
                        color: Color(0xFF50616B),
                      ),
                      title: const Text('Privacy policy'),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF9BA8AE),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      onTap: () => _showPolicy(context, 'Terms of use'),
                      leading: const Icon(
                        Icons.description_outlined,
                        color: Color(0xFF50616B),
                      ),
                      title: const Text('Terms of use'),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF9BA8AE),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'eSign : Sign Any Docs • Version 1.0.0',
                  style: TextStyle(fontSize: 12, color: Color(0xFF87939A)),
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> _manageSubscription() async {
    final uri = Platform.isIOS
        ? Uri.parse('https://apps.apple.com/account/subscriptions')
        : Uri.parse(
            'https://play.google.com/store/account/subscriptions?package=com.esign.signanydocs',
          );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open subscription settings.'),
        ),
      );
    }
  }

  Future<void> _openPremiumWall() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (paywallContext) => StartupPaywallScreen(
          onContinue: () => Navigator.of(paywallContext).pop(),
        ),
      ),
    );
  }

  Future<void> _restorePurchases() async {
    if (restoring) return;
    setState(() => restoring = true);
    final billing = SubscriptionService();
    await billing.initialize(
      onEntitlementChanged: (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase restored successfully.')),
          );
        }
      },
    );
    await billing.restorePurchases();
    await billing.dispose();
    if (!mounted) return;
    setState(() => restoring = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Restore request sent to the app store.')),
    );
  }

  void _showLanguage(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Language'),
        content: const Text(
          'English is currently the available language. More languages can be added without changing your saved documents.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showPolicy(BuildContext context, String title) {
    final url = Uri.parse(title == 'Privacy policy'
        ? 'https://github.com/waqarm6/esign-sign-any-docs/blob/main/PRIVACY_POLICY.md'
        : 'https://github.com/waqarm6/esign-sign-any-docs/blob/main/TERMS_OF_USE.md');
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(
          title == 'Privacy policy'
              ? 'Documents and annotation drafts stay on this device unless you choose to export or share them. Camera and file access are used only when you request scanning or importing.'
              : 'eSign : Sign Any Docs lets you edit documents locally. Export and sharing require an active trial or subscription, which renews until cancelled through the app store.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            },
            child: const Text('Open full policy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _SettingsHeading extends StatelessWidget {
  final String text;
  const _SettingsHeading(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
            color: Color(0xFF718087),
          ),
        ),
      );
}

class DocumentLibraryScreen extends StatefulWidget {
  final DocumentStatus? initialFilter;
  const DocumentLibraryScreen({super.key, this.initialFilter});
  @override
  State<DocumentLibraryScreen> createState() => _DocumentLibraryScreenState();
}

class _DocumentLibraryScreenState extends State<DocumentLibraryScreen>
    with SingleTickerProviderStateMixin {
  final store = DocumentStore();
  late Future<List<DocumentRecord>> documents;
  List<DocumentRecord> lastDocuments = const <DocumentRecord>[];
  String? activeAction;
  late final TabController tabController;

  @override
  void initState() {
    super.initState();
    documents = store.loadDocuments();
    tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialFilter == DocumentStatus.completed ? 1 : 0,
    );
    tabController.addListener(_onTabChanged);
    DocumentStore.changes.addListener(_refreshDocuments);
  }

  @override
  void dispose() {
    DocumentStore.changes.removeListener(_refreshDocuments);
    tabController.removeListener(_onTabChanged);
    tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  void _refreshDocuments() {
    if (!mounted) return;
    setState(() {
      lastDocuments = DocumentStore.currentDocuments;
      documents = Future.value(lastDocuments);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Documents',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ),
        body: SafeArea(
          child: FutureBuilder<List<DocumentRecord>>(
            future: documents,
            builder: (context, snapshot) {
              final items = snapshot.data ?? lastDocuments;
              if (snapshot.hasData) lastDocuments = items;
              final draftCount = items
                  .where((item) => item.status == DocumentStatus.draft)
                  .length;
              final completedCount = items.length - draftCount;
              final filtered = items
                  .where(
                    (item) =>
                        item.status ==
                        (tabController.index == 0
                            ? DocumentStatus.draft
                            : DocumentStatus.completed),
                  )
                  .toList();
              return Column(children: [
                Material(
                  color: Colors.white,
                  child: TabBar(
                    controller: tabController,
                    tabs: [
                      Tab(text: 'Drafts  $draftCount'),
                      Tab(text: 'Completed  $completedCount'),
                    ],
                  ),
                ),
                if (activeAction != null)
                  Semantics(
                    liveRegion: true,
                    label: activeAction,
                    child: Column(
                      children: [
                        const LinearProgressIndicator(minHeight: 3),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 10),
                              Text(activeAction!),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                    child: snapshot.connectionState ==
                                ConnectionState.waiting &&
                            items.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : filtered.isEmpty
                            ? _EmptyDocuments(
                                message: tabController.index == 0
                                    ? 'Scan or import a document to start a draft.'
                                    : 'Completed documents will appear here after export.',
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 16, 20, 24),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  return Card(
                                    child: ListTile(
                                      onTap: () async {
                                        final exportedPath = item.exportedPath;
                                        if (item.status ==
                                                DocumentStatus.completed &&
                                            exportedPath != null &&
                                            await File(exportedPath).exists()) {
                                          await Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ExportedPdfViewerScreen(
                                                title: item.name,
                                                path: exportedPath,
                                                onEdit: () =>
                                                    Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        DocumentWorkspace(
                                                      title: item.name,
                                                      sourcePath:
                                                          item.sourcePath,
                                                      documentId: item.id,
                                                      savedDraft:
                                                          item.draftData,
                                                      status: item.status,
                                                      createdAt: item.createdAt,
                                                      pageCount: item.pageCount,
                                                      exportedPath:
                                                          item.exportedPath,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => DocumentWorkspace(
                                              title: item.name,
                                              sourcePath: item.sourcePath,
                                              documentId: item.id,
                                              savedDraft: item.draftData,
                                              status: item.status,
                                              createdAt: item.createdAt,
                                              pageCount: item.pageCount,
                                              exportedPath: item.exportedPath,
                                            ),
                                          ),
                                        );
                                      },
                                      leading: _DocumentThumbnail(item: item),
                                      title: Text(
                                        item.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      subtitle: Text(
                                        '${item.status == DocumentStatus.draft ? 'Draft' : 'Completed'} • ${item.pageCount} page${item.pageCount == 1 ? '' : 's'} • ${_formatDocumentDate(item.updatedAt)}',
                                      ),
                                      trailing: PopupMenuButton<String>(
                                        enabled: activeAction == null,
                                        onSelected: (action) async {
                                          if (action == 'rename')
                                            await _renameDocument(item);
                                          if (action == 'delete')
                                            await _deleteDocument(item);
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                              value: 'rename',
                                              child: Text('Rename')),
                                          PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Delete')),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              )),
              ]);
            },
          ),
        ),
      );

  Future<void> _renameDocument(DocumentRecord item) async {
    final controller = TextEditingController(text: item.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Document name'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == item.name) return;
    await _runDocumentAction(
        'Renaming document…',
        () => store.saveDocument(
              item.copyWith(name: trimmed, updatedAt: DateTime.now()),
            ));
  }

  Future<void> _deleteDocument(DocumentRecord item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('Remove “${item.name}” from this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB23A3A),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runDocumentAction(
        'Deleting document…', () => store.deleteDocument(item.id));
  }

  Future<void> _runDocumentAction(
    String label,
    Future<void> Function() action,
  ) async {
    if (activeAction != null) return;
    setState(() => activeAction = label);
    final minimumVisibility =
        Future<void>.delayed(const Duration(milliseconds: 400));
    try {
      await action();
      await minimumVisibility;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Action failed: $error'),
        ));
      }
    } finally {
      if (mounted) setState(() => activeAction = null);
    }
  }
}

class _EmptyDocuments extends StatelessWidget {
  final String message;
  const _EmptyDocuments({
    this.message = 'Scan or import a document to see it here.',
  });
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5F5),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.folder_open_outlined,
                  size: 34,
                  color: Color(0xFF0E7490),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No documents yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF62707B)),
              ),
            ],
          ),
        ),
      );
}

class _DocumentSourcePreview extends StatefulWidget {
  final String? path;
  final int pageIndex;
  final ValueChanged<int> onPageCount;

  const _DocumentSourcePreview({
    required this.path,
    required this.pageIndex,
    required this.onPageCount,
  });

  @override
  State<_DocumentSourcePreview> createState() => _DocumentSourcePreviewState();
}

class _ExportPageImage {
  final Uint8List bytes;
  final int width;
  final int height;

  const _ExportPageImage({
    required this.bytes,
    required this.width,
    required this.height,
  });
}

class ExportedPdfViewerScreen extends StatefulWidget {
  final String title;
  final String path;
  final Future<void> Function()? onEdit;

  const ExportedPdfViewerScreen({
    super.key,
    required this.title,
    required this.path,
    this.onEdit,
  });

  @override
  State<ExportedPdfViewerScreen> createState() =>
      _ExportedPdfViewerScreenState();
}

class _ExportedPdfViewerScreenState extends State<ExportedPdfViewerScreen> {
  final List<PdfRaster> pages = <PdfRaster>[];
  final List<PdfRasterImage> pageImages = <PdfRasterImage>[];
  final PageController pageController = PageController();
  bool loading = true;
  String? error;
  int currentPage = 0;
  int fileBytes = 0;

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPages() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
        pages.clear();
        pageImages.clear();
        currentPage = 0;
      });
    }
    if (pageController.hasClients) pageController.jumpToPage(0);
    try {
      final file = File(widget.path);
      if (!await file.exists()) {
        throw StateError('The saved PDF is no longer available.');
      }
      final bytes = await file.readAsBytes();
      fileBytes = bytes.length;
      await for (final raster in Printing.raster(bytes, dpi: 144)) {
        if (!mounted) return;
        setState(() {
          pages.add(raster);
          pageImages.add(PdfRasterImage(raster));
        });
      }
      if (pages.isEmpty) throw StateError('The saved PDF has no pages.');
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String get fileDetails {
    final size = fileBytes >= 1024 * 1024
        ? '${(fileBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(fileBytes / 1024).toStringAsFixed(0)} KB';
    return 'PDF  •  ${pages.length} page${pages.length == 1 ? '' : 's'}  •  $size';
  }

  void _goToPage(int page) {
    if (page < 0 || page >= pages.length || !pageController.hasClients) return;
    pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _editDocument() async {
    await widget.onEdit?.call();
    if (mounted) await _loadPages();
  }

  Future<void> _sharePdf() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      await Printing.sharePdf(
        bytes: bytes,
        filename: widget.path.split(Platform.pathSeparator).last,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to share this PDF.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PDF preview',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (widget.onEdit != null)
            IconButton(
              tooltip: 'Edit document',
              onPressed: _editDocument,
              icon: const Icon(Icons.edit_outlined),
            ),
          IconButton(
            tooltip: 'Share PDF',
            onPressed: _sharePdf,
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.picture_as_pdf_outlined,
                            size: 44, color: Color(0xFF8B9AA2)),
                        const SizedBox(height: 16),
                        const Text('Could not open this PDF',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        TextButton(
                            onPressed: _loadPages,
                            child: const Text('Try again')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBEDEC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.picture_as_pdf_outlined,
                                color: Color(0xFFB23A3A)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF17212B))),
                                const SizedBox(height: 4),
                                Text(fileDetails,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF62707B))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        color: const Color(0xFFE9EFF2),
                        child: PageView.builder(
                          controller: pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: pages.length,
                          onPageChanged: (page) =>
                              setState(() => currentPage = page),
                          itemBuilder: (_, index) => LayoutBuilder(
                            builder: (context, constraints) {
                              final raster = pages[index];
                              final fit = math.min(
                                math.max(1, constraints.maxWidth - 32) /
                                    raster.width,
                                math.max(1, constraints.maxHeight - 32) /
                                    raster.height,
                              );
                              return InteractiveViewer(
                                minScale: 1,
                                maxScale: 4,
                                child: Center(
                                  child: Container(
                                    width: raster.width * fit,
                                    height: raster.height * fit,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0x240F3444),
                                          blurRadius: 18,
                                          offset: Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Image(
                                      image: pageImages[index],
                                      fit: BoxFit.fill,
                                      gaplessPlayback: true,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Previous page',
                              onPressed: currentPage > 0
                                  ? () => _goToPage(currentPage - 1)
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Expanded(
                              child: Text(
                                'Page ${currentPage + 1} of ${pages.length}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF33434C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Next page',
                              onPressed: currentPage < pages.length - 1
                                  ? () => _goToPage(currentPage + 1)
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _DocumentSourcePreviewState extends State<_DocumentSourcePreview> {
  final List<PdfRaster> pdfPages = <PdfRaster>[];
  final List<PdfRasterImage> pdfImages = <PdfRasterImage>[];
  FileImage? fileImage;
  bool loadingPdf = false;

  @override
  void initState() {
    super.initState();
    if (widget.path?.toLowerCase().endsWith('.pdf') == true) {
      _loadPdf();
    } else {
      if (widget.path != null) fileImage = FileImage(File(widget.path!));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onPageCount(1);
      });
    }
  }

  @override
  void didUpdateWidget(covariant _DocumentSourcePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      pdfPages.clear();
      pdfImages.clear();
      fileImage = null;
      if (widget.path?.toLowerCase().endsWith('.pdf') == true) {
        _loadPdf();
      } else if (widget.path != null) {
        fileImage = FileImage(File(widget.path!));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onPageCount(1);
        });
      }
    }
  }

  Future<void> _loadPdf() async {
    final path = widget.path;
    if (path == null || path.isEmpty) return;
    setState(() => loadingPdf = true);
    try {
      final bytes = await File(path).readAsBytes();
      await for (final raster in Printing.raster(bytes, dpi: 144)) {
        if (!mounted) return;
        setState(() {
          pdfPages.add(raster);
          pdfImages.add(PdfRasterImage(raster));
        });
        widget.onPageCount(pdfPages.length);
      }
    } catch (_) {
      // The parent keeps the empty-document state if the PDF cannot rasterize.
    } finally {
      if (mounted) setState(() => loadingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.path;
    if (path == null || path.isEmpty) return const _PlaceholderDocumentPage();
    if (path.toLowerCase().endsWith('.pdf')) {
      if (pdfPages.isNotEmpty && widget.pageIndex < pdfPages.length) {
        return Image(
          image: pdfImages[widget.pageIndex],
          fit: BoxFit.contain,
          gaplessPlayback: true,
        );
      }
      return Container(
        color: const Color(0xFFF4F7F8),
        child: Center(
          child: loadingPdf
              ? const CircularProgressIndicator()
              : const Text(
                  'This PDF page could not be previewed on this device.',
                  textAlign: TextAlign.center,
                ),
        ),
      );
    }
    return Image(
      image: fileImage ??= FileImage(File(path)),
      fit: BoxFit.contain,
      alignment: Alignment.center,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const _PlaceholderDocumentPage(),
    );
  }
}

String _formatDocumentDate(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  final sameDay = local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  if (sameDay) {
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return 'Today, $hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}

class _DocumentThumbnail extends StatelessWidget {
  final DocumentRecord item;
  const _DocumentThumbnail({required this.item});

  @override
  Widget build(BuildContext context) {
    final path = item.sourcePath;
    final hasImage =
        path != null && path.isNotEmpty && !path.toLowerCase().endsWith('.pdf');
    if (hasImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(path),
          width: 48,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() => CircleAvatar(
        backgroundColor: item.status == DocumentStatus.draft
            ? const Color(0xFFFFF4D6)
            : const Color(0xFFE5F4F5),
        foregroundColor: item.status == DocumentStatus.draft
            ? const Color(0xFF8A6B18)
            : const Color(0xFF0E7490),
        child: Icon(
          item.status == DocumentStatus.draft
              ? Icons.edit_note_outlined
              : Icons.check_circle_outline,
        ),
      );
}

class _PlaceholderDocumentPage extends StatelessWidget {
  const _PlaceholderDocumentPage();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DOCUMENT PREVIEW',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0E7490),
                  ),
            ),
            const SizedBox(height: 26),
            Container(height: 12, width: 190, color: const Color(0xFF17212B)),
            const SizedBox(height: 18),
            ...List.generate(
              9,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  height: 7,
                  width: index % 3 == 2 ? 150 : double.infinity,
                  color: const Color(0xFFE4E9EB),
                ),
              ),
            ),
            const Spacer(),
            Container(
              height: 72,
              width: 185,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFB9C6CB)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'Signature',
                  style: TextStyle(
                    fontFamily: 'cursive',
                    fontSize: 22,
                    color: Color(0xFF0E7490),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _PrimaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PrimaryAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          child: Container(
            height: 132,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: label.startsWith('Scan')
                  ? const Color(0xFF173B4B)
                  : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: label.startsWith('Scan')
                  ? null
                  : Border.all(color: const Color(0xFFE1E8EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: label.startsWith('Scan')
                      ? Colors.white
                      : const Color(0xFF0E7490),
                  size: 28,
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: label.startsWith('Scan')
                        ? Colors.white
                        : const Color(0xFF17212B),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _CountCard extends StatelessWidget {
  final String label, count;
  final IconData icon;
  final VoidCallback? onTap;
  const _CountCard({
    required this.label,
    required this.count,
    required this.icon,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF0E7490)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(label, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback onTap;
  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (action != null)
            TextButton(onPressed: onTap, child: Text(action!)),
        ],
      );
}

class _ToolRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _ToolRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE5F4F5),
          foregroundColor: const Color(0xFF0E7490),
          child: Icon(icon, size: 20),
        ),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF9BA8AE)),
      );
}

class DocumentWorkspace extends StatefulWidget {
  final String title;
  final String? sourcePath;
  final String? exportedPath;
  final String? documentId;
  final Map<String, dynamic>? savedDraft;
  final DocumentStatus status;
  final DateTime? createdAt;
  final int pageCount;
  const DocumentWorkspace({
    super.key,
    required this.title,
    this.sourcePath,
    this.exportedPath,
    this.documentId,
    this.savedDraft,
    this.status = DocumentStatus.draft,
    this.createdAt,
    this.pageCount = 1,
  });

  @override
  State<DocumentWorkspace> createState() => _DocumentWorkspaceState();
}

enum _EditorField { signature, text, date, checkbox, stamp }

enum _ExportAction { share, export }

class _FieldTransform {
  final Offset position;
  final double scale;
  final double rotation;
  const _FieldTransform(this.position, this.scale, this.rotation);
}

Offset _rotateOffset(Offset value, double angle) {
  final cosine = math.cos(angle);
  final sine = math.sin(angle);
  return Offset(
    value.dx * cosine - value.dy * sine,
    value.dx * sine + value.dy * cosine,
  );
}

class _DocumentWorkspaceState extends State<DocumentWorkspace>
    with WidgetsBindingObserver {
  double signatureX = 54;
  double signatureY = 310;
  double signatureScale = 1;
  double signatureRotation = 0;
  bool signaturePlaced = false;
  _EditorField? selectedField;
  bool textPlaced = false;
  bool datePlaced = false;
  bool checkboxPlaced = false;
  bool stampPlaced = false;
  Uint8List? stampImageBytes;
  String? stampImagePath;
  List<SignatureStroke> signatureStrokes = <SignatureStroke>[];
  String textValue = '';
  Color textColor = const Color(0xFF173B4B);
  double textFontSize = 14;
  String textFontFamily = 'Inter';
  DateTime selectedDate = DateTime.now();
  Color dateColor = const Color(0xFF173B4B);
  double dateFontSize = 14;
  String dateFontFamily = 'Inter';
  bool checkboxValue = false;
  Color checkboxColor = const Color(0xFF173B4B);
  String stampText = 'APPROVED';
  Color stampColor = const Color(0xFF0E7490);
  String stampFontFamily = 'Roboto Slab';
  Offset textPosition = const Offset(54, 220);
  Offset datePosition = const Offset(54, 250);
  Offset checkboxPosition = const Offset(54, 280);
  Offset stampPosition = const Offset(54, 400);
  double textScale = 1;
  double dateScale = 1;
  double checkboxScale = 1;
  double stampScale = 1;
  double textRotation = 0;
  double dateRotation = 0;
  double checkboxRotation = 0;
  double stampRotation = 0;
  final documentStore = DocumentStore();
  final GlobalKey _documentPreviewKey = GlobalKey();
  _DocumentSourcePreview? cachedSourcePreview;
  final Map<_EditorField, GlobalKey<_MovableFieldState>> _movableFieldKeys =
      <_EditorField, GlobalKey<_MovableFieldState>>{
    _EditorField.signature: GlobalKey<_MovableFieldState>(),
    _EditorField.text: GlobalKey<_MovableFieldState>(),
    _EditorField.date: GlobalKey<_MovableFieldState>(),
    _EditorField.checkbox: GlobalKey<_MovableFieldState>(),
    _EditorField.stamp: GlobalKey<_MovableFieldState>(),
  };
  final List<Map<String, dynamic>> _pageDrafts = <Map<String, dynamic>>[];
  int currentPage = 0;
  int documentPageCount = 1;
  late final String draftId;
  late DocumentStatus documentStatus;
  late final DateTime draftCreatedAt;
  String? exportedPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    draftId =
        widget.documentId ?? 'draft_${DateTime.now().millisecondsSinceEpoch}';
    documentStatus = widget.status;
    exportedPath = widget.exportedPath;
    draftCreatedAt = widget.createdAt ?? DateTime.now();
    documentPageCount = math.max(1, widget.pageCount);
    if (widget.savedDraft == null) {
      _saveDraft();
    } else {
      _restoreDraft(widget.savedDraft!);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DocumentWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourcePath != widget.sourcePath) {
      cachedSourcePreview = null;
    }
  }

  _DocumentSourcePreview _sourcePreview() =>
      cachedSourcePreview ??= _DocumentSourcePreview(
        path: widget.sourcePath,
        pageIndex: currentPage,
        onPageCount: _setDocumentPageCount,
      );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _commitActiveTransforms();
      _saveDraft();
    }
  }

  void _commitActiveTransforms() {
    for (final key in _movableFieldKeys.values) {
      key.currentState?._finishTransform();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _closeWorkspace();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              Text(
                'Page ${currentPage + 1} of $documentPageCount  •  ${widget.sourcePath?.toLowerCase().endsWith('.pdf') == true ? 'PDF' : 'Image'}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF62707B)),
              ),
            ],
          ),
          leading: IconButton(
            onPressed: _closeWorkspace,
            icon: const Icon(Icons.close),
          ),
          actions: [
            IconButton(
              onPressed: () => _showExportActions(context),
              icon: const Icon(Icons.ios_share_outlined),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9EFF2),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 18,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: RepaintBoundary(
                  key: _documentPreviewKey,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: RepaintBoundary(
                            child: _sourcePreview(),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => selectedField = null),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4F5),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Previous page',
                                onPressed: currentPage == 0
                                    ? null
                                    : () => _switchPage(currentPage - 1),
                                icon: const Icon(Icons.chevron_left, size: 18),
                              ),
                              Text(
                                'Page ${currentPage + 1} of $documentPageCount',
                                style: const TextStyle(fontSize: 11),
                              ),
                              IconButton(
                                tooltip: 'Next page',
                                onPressed: currentPage >= documentPageCount - 1
                                    ? null
                                    : () => _switchPage(currentPage + 1),
                                icon: const Icon(Icons.chevron_right, size: 18),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (signaturePlaced)
                        _MovableField(
                          key: _movableFieldKeys[_EditorField.signature],
                          position: Offset(signatureX, signatureY),
                          scale: signatureScale,
                          rotation: signatureRotation,
                          selected: selectedField == _EditorField.signature,
                          child: SizedBox(
                            width: 188,
                            height: 74,
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: _SignaturePainter(
                                  signatureStrokes,
                                  showGuide: false,
                                  fitToCanvas: true,
                                ),
                              ),
                            ),
                          ),
                          onTransform: (value) => setState(() {
                            signatureX = value.position.dx;
                            signatureY = value.position.dy;
                            signatureScale = value.scale;
                            signatureRotation = value.rotation;
                          }),
                          onTap: () => setState(
                            () => selectedField = _EditorField.signature,
                          ),
                          onLongPress: _showSignatureActions,
                        ),
                      if (textPlaced)
                        _MovableField(
                          key: _movableFieldKeys[_EditorField.text],
                          position: textPosition,
                          scale: textScale,
                          rotation: textRotation,
                          selected: selectedField == _EditorField.text,
                          child: Text(
                            textValue.isEmpty ? 'Tap to add text' : textValue,
                            style: _annotationTextStyle(
                                textFontFamily, textFontSize, textColor),
                          ),
                          onMoved: (value) =>
                              setState(() => textPosition = value),
                          onTap: () =>
                              setState(() => selectedField = _EditorField.text),
                          onDoubleTap: _editText,
                          onTransform: (value) => setState(() {
                            textPosition = value.position;
                            textScale = value.scale;
                            textRotation = value.rotation;
                          }),
                        ),
                      if (datePlaced)
                        _MovableField(
                          key: _movableFieldKeys[_EditorField.date],
                          position: datePosition,
                          scale: dateScale,
                          rotation: dateRotation,
                          selected: selectedField == _EditorField.date,
                          child: Text(
                            _formattedDate(selectedDate),
                            style: _annotationTextStyle(
                                dateFontFamily, dateFontSize, dateColor),
                          ),
                          onMoved: (value) =>
                              setState(() => datePosition = value),
                          onTap: () =>
                              setState(() => selectedField = _EditorField.date),
                          onDoubleTap: _chooseDate,
                          onTransform: (value) => setState(() {
                            datePosition = value.position;
                            dateScale = value.scale;
                            dateRotation = value.rotation;
                          }),
                        ),
                      if (checkboxPlaced)
                        _MovableField(
                          key: _movableFieldKeys[_EditorField.checkbox],
                          position: checkboxPosition,
                          scale: checkboxScale,
                          rotation: checkboxRotation,
                          selected: selectedField == _EditorField.checkbox,
                          child: Icon(
                            checkboxValue
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            color: checkboxColor,
                            size: 25,
                          ),
                          onMoved: (value) =>
                              setState(() => checkboxPosition = value),
                          onTap: () => setState(() {
                            selectedField = _EditorField.checkbox;
                            checkboxValue = !checkboxValue;
                          }),
                          onTransform: (value) => setState(() {
                            checkboxPosition = value.position;
                            checkboxScale = value.scale;
                            checkboxRotation = value.rotation;
                          }),
                        ),
                      if (stampPlaced)
                        _MovableField(
                          key: _movableFieldKeys[_EditorField.stamp],
                          position: stampPosition,
                          scale: stampScale,
                          rotation: stampRotation,
                          selected: selectedField == _EditorField.stamp,
                          child:
                              stampImageBytes != null || stampImagePath != null
                                  ? _StampImageField(
                                      bytes: stampImageBytes,
                                      path: stampImagePath,
                                    )
                                  : _StampField(
                                      text: stampText,
                                      color: stampColor,
                                      fontFamily: stampFontFamily,
                                    ),
                          onMoved: (value) =>
                              setState(() => stampPosition = value),
                          onTap: () => setState(
                              () => selectedField = _EditorField.stamp),
                          onDoubleTap: _chooseStamp,
                          onTransform: (value) => setState(() {
                            stampPosition = value.position;
                            stampScale = value.scale;
                            stampRotation = value.rotation;
                          }),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE3E9EB))),
                ),
                child: Column(
                  children: [
                    if (selectedField != null) ...[
                      _AnnotationToolbar(
                        label: _selectedFieldLabel(),
                        onRotateLeft: () => _rotateSelected(-0.12),
                        onRotateRight: () => _rotateSelected(0.12),
                        onScaleDown: () => _scaleSelected(-0.1),
                        onScaleUp: () => _scaleSelected(0.1),
                        onStyle: _openStylePanel,
                        onDelete: _deleteSelected,
                      ),
                      const SizedBox(height: 8),
                    ],
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _EditorTool(
                            icon: Icons.draw_outlined,
                            label: 'Signature',
                            onTap: () => _openSignatureCreator(context),
                          ),
                          _EditorTool(
                            icon: Icons.text_fields_outlined,
                            label: 'Text',
                            onTap: _addText,
                          ),
                          _EditorTool(
                            icon: Icons.today_outlined,
                            label: 'Date',
                            onTap: _addDate,
                          ),
                          _EditorTool(
                            icon: Icons.check_box_outlined,
                            label: 'Checkbox',
                            onTap: () => setState(() {
                              checkboxPlaced = true;
                              selectedField = _EditorField.checkbox;
                            }),
                          ),
                          _EditorTool(
                            icon: Icons.verified_outlined,
                            label: 'Stamp',
                            onTap: _addStamp,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saveDraftAndClose,
                            icon: const Icon(Icons.drafts_outlined),
                            label: const Text('Save draft'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _showExportActions(context),
                            icon: const Icon(Icons.lock_outline),
                            label: const Text('Export & share'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Drafts stay on this device. Export and sharing require a trial or subscription.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Color(0xFF718087)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _selectedFieldLabel() {
    switch (selectedField) {
      case _EditorField.signature:
        return 'Signature';
      case _EditorField.text:
        return 'Text';
      case _EditorField.date:
        return 'Date';
      case _EditorField.checkbox:
        return 'Checkbox';
      case _EditorField.stamp:
        return 'Stamp';
      case null:
        return '';
    }
  }

  void _scaleSelected(double delta) {
    setState(() {
      switch (selectedField) {
        case _EditorField.signature:
          signatureScale = (signatureScale + delta).clamp(.5, 3.0).toDouble();
          break;
        case _EditorField.text:
          textScale = (textScale + delta).clamp(.5, 3.0).toDouble();
          break;
        case _EditorField.date:
          dateScale = (dateScale + delta).clamp(.5, 3.0).toDouble();
          break;
        case _EditorField.checkbox:
          checkboxScale = (checkboxScale + delta).clamp(.5, 3.0).toDouble();
          break;
        case _EditorField.stamp:
          stampScale = (stampScale + delta).clamp(.5, 3.0).toDouble();
          break;
        case null:
          break;
      }
    });
  }

  void _rotateSelected(double delta) {
    setState(() {
      switch (selectedField) {
        case _EditorField.signature:
          signatureRotation += delta;
          break;
        case _EditorField.text:
          textRotation += delta;
          break;
        case _EditorField.date:
          dateRotation += delta;
          break;
        case _EditorField.checkbox:
          checkboxRotation += delta;
          break;
        case _EditorField.stamp:
          stampRotation += delta;
          break;
        case null:
          break;
      }
    });
  }

  void _deleteSelected() {
    setState(() {
      switch (selectedField) {
        case _EditorField.signature:
          signaturePlaced = false;
          signatureStrokes = <SignatureStroke>[];
          break;
        case _EditorField.text:
          textPlaced = false;
          break;
        case _EditorField.date:
          datePlaced = false;
          break;
        case _EditorField.checkbox:
          checkboxPlaced = false;
          break;
        case _EditorField.stamp:
          stampPlaced = false;
          stampImageBytes = null;
          stampImagePath = null;
          break;
        case null:
          break;
      }
      selectedField = null;
    });
  }

  Color _selectedFieldColor() {
    switch (selectedField) {
      case _EditorField.text:
        return textColor;
      case _EditorField.date:
        return dateColor;
      case _EditorField.checkbox:
        return checkboxColor;
      case _EditorField.stamp:
        return stampColor;
      case _EditorField.signature:
      case null:
        return const Color(0xFF173B4B);
    }
  }

  void _applySelectedColor(Color color) {
    switch (selectedField) {
      case _EditorField.text:
        textColor = color;
        break;
      case _EditorField.date:
        dateColor = color;
        break;
      case _EditorField.checkbox:
        checkboxColor = color;
        break;
      case _EditorField.stamp:
        stampColor = color;
        break;
      case _EditorField.signature:
      case null:
        break;
    }
  }

  String _selectedFontFamily() {
    switch (selectedField) {
      case _EditorField.text:
        return textFontFamily;
      case _EditorField.date:
        return dateFontFamily;
      case _EditorField.stamp:
        return stampFontFamily;
      case _EditorField.signature:
      case _EditorField.checkbox:
      case null:
        return 'Inter';
    }
  }

  void _applySelectedFont(String fontFamily) {
    switch (selectedField) {
      case _EditorField.text:
        textFontFamily = fontFamily;
        break;
      case _EditorField.date:
        dateFontFamily = fontFamily;
        break;
      case _EditorField.stamp:
        stampFontFamily = fontFamily;
        break;
      case _EditorField.signature:
      case _EditorField.checkbox:
      case null:
        break;
    }
  }

  Future<void> _openStylePanel() async {
    final field = selectedField;
    if (field == null) return;
    if (field == _EditorField.signature) {
      _openSignatureCreator(context);
      return;
    }
    var color = _selectedFieldColor();
    var fontFamily = _selectedFontFamily();
    final supportsFont = field == _EditorField.text ||
        field == _EditorField.date ||
        (field == _EditorField.stamp &&
            stampImageBytes == null &&
            stampImagePath == null);
    var fontSize = field == _EditorField.date ? dateFontSize : textFontSize;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Style ${_selectedFieldLabel()}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (field != _EditorField.stamp ||
                    (stampImageBytes == null && stampImagePath == null))
                  Row(
                    children: [
                      const Text(
                        'Color',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 14),
                      for (final option in _annotationColors)
                        _StyleColorDot(
                          color: option,
                          selected: color == option,
                          onTap: () {
                            setSheetState(() => color = option);
                            setState(() => _applySelectedColor(option));
                          },
                        ),
                    ],
                  ),
                if (supportsFont) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: fontFamily,
                    decoration: const InputDecoration(
                      labelText: 'Font',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _annotationFontFamilies
                        .map(
                          (font) => DropdownMenuItem<String>(
                            value: font,
                            child: Text(
                              font,
                              style: GoogleFonts.getFont(font),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() => fontFamily = value);
                      setState(() => _applySelectedFont(value));
                    },
                  ),
                ],
                if (field == _EditorField.text ||
                    field == _EditorField.date) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Size',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Expanded(
                        child: Slider(
                          value: fontSize,
                          min: 10,
                          max: 28,
                          divisions: 9,
                          label: '${fontSize.round()} px',
                          onChanged: (value) {
                            setSheetState(() => fontSize = value);
                            setState(() {
                              if (field == _EditorField.date) {
                                dateFontSize = value;
                              } else {
                                textFontSize = value;
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _buildPageDraftData() => {
        'signaturePlaced': signaturePlaced,
        'signatureStrokes': signatureStrokes
            .map(
              (stroke) => {
                'color': stroke.colorValue,
                'width': stroke.width,
                'points': stroke.points
                    .map((point) => {'x': point.dx, 'y': point.dy})
                    .toList(),
              },
            )
            .toList(),
        'signatureX': signatureX,
        'signatureY': signatureY,
        'signatureScale': signatureScale,
        'signatureRotation': signatureRotation,
        'textPlaced': textPlaced,
        'textValue': textValue,
        'textColor': textColor.value,
        'textFontSize': textFontSize,
        'textFontFamily': textFontFamily,
        'textPosition': _offsetToJson(textPosition),
        'textScale': textScale,
        'textRotation': textRotation,
        'datePlaced': datePlaced,
        'selectedDate': selectedDate.toIso8601String(),
        'dateColor': dateColor.value,
        'dateFontSize': dateFontSize,
        'dateFontFamily': dateFontFamily,
        'datePosition': _offsetToJson(datePosition),
        'dateScale': dateScale,
        'dateRotation': dateRotation,
        'checkboxPlaced': checkboxPlaced,
        'checkboxValue': checkboxValue,
        'checkboxColor': checkboxColor.value,
        'checkboxPosition': _offsetToJson(checkboxPosition),
        'checkboxScale': checkboxScale,
        'checkboxRotation': checkboxRotation,
        'stampPlaced': stampPlaced,
        'stampText': stampText,
        'stampColor': stampColor.value,
        'stampFontFamily': stampFontFamily,
        'stampImagePath': stampImagePath,
        'stampPosition': _offsetToJson(stampPosition),
        'stampScale': stampScale,
        'stampRotation': stampRotation,
      };

  Map<String, dynamic> _buildDraftData() {
    final current = _buildPageDraftData();
    final pages = List<Map<String, dynamic>>.generate(
      documentPageCount,
      (index) => index == currentPage
          ? current
          : (index < _pageDrafts.length
              ? _pageDrafts[index]
              : <String, dynamic>{}),
    );
    return {
      ...current,
      'pages': pages,
      'currentPage': currentPage,
    };
  }

  Map<String, double> _offsetToJson(Offset offset) => {
        'x': offset.dx,
        'y': offset.dy,
      };

  Offset _offsetFromJson(dynamic value, Offset fallback) {
    if (value is! Map) return fallback;
    final x = value['x'];
    final y = value['y'];
    if (x is! num || y is! num) return fallback;
    return Offset(x.toDouble(), y.toDouble());
  }

  Color _colorFromJson(dynamic value, Color fallback) {
    return value is num ? Color(value.toInt()) : fallback;
  }

  double _doubleFromJson(dynamic value, double fallback) {
    return value is num ? value.toDouble() : fallback;
  }

  String _fontFromJson(dynamic value, String fallback) {
    return value is String && _annotationFontFamilies.contains(value)
        ? value
        : fallback;
  }

  void _setDocumentPageCount(int count) {
    final nextCount = math.max(1, count);
    if (nextCount == documentPageCount) return;
    if (!mounted) return;
    setState(() {
      documentPageCount = nextCount;
      while (_pageDrafts.length < documentPageCount) {
        _pageDrafts.add(<String, dynamic>{});
      }
      if (currentPage >= documentPageCount) {
        currentPage = documentPageCount - 1;
        cachedSourcePreview = null;
      }
    });
  }

  void _resetPageState() {
    signatureX = 54;
    signatureY = 310;
    signatureScale = 1;
    signatureRotation = 0;
    signaturePlaced = false;
    signatureStrokes = <SignatureStroke>[];
    textPlaced = false;
    textValue = '';
    textColor = const Color(0xFF173B4B);
    textFontSize = 14;
    textFontFamily = 'Inter';
    datePlaced = false;
    selectedDate = DateTime.now();
    dateColor = const Color(0xFF173B4B);
    dateFontSize = 14;
    dateFontFamily = 'Inter';
    checkboxPlaced = false;
    checkboxValue = false;
    checkboxColor = const Color(0xFF173B4B);
    stampPlaced = false;
    stampText = 'APPROVED';
    stampColor = const Color(0xFF0E7490);
    stampFontFamily = 'Roboto Slab';
    stampImageBytes = null;
    stampImagePath = null;
    textPosition = const Offset(54, 220);
    datePosition = const Offset(54, 250);
    checkboxPosition = const Offset(54, 280);
    stampPosition = const Offset(54, 400);
    textScale = 1;
    dateScale = 1;
    checkboxScale = 1;
    stampScale = 1;
    textRotation = 0;
    dateRotation = 0;
    checkboxRotation = 0;
    stampRotation = 0;
    selectedField = null;
  }

  void _switchPage(int index) {
    if (index < 0 || index >= documentPageCount || index == currentPage) {
      return;
    }
    while (_pageDrafts.length < documentPageCount) {
      _pageDrafts.add(<String, dynamic>{});
    }
    _pageDrafts[currentPage] = _buildPageDraftData();
    final next = _pageDrafts[index];
    setState(() {
      currentPage = index;
      cachedSourcePreview = null;
      _resetPageState();
      if (next.isNotEmpty) _restorePageDraft(next);
    });
    _saveDraft();
  }

  void _restoreDraft(Map<String, dynamic> data) {
    final rawPages = data['pages'];
    if (rawPages is List && rawPages.isNotEmpty) {
      _pageDrafts
        ..clear()
        ..addAll(
          rawPages.whereType<Map>().map(
                (page) => page.cast<String, dynamic>(),
              ),
        );
      documentPageCount = math.max(1, _pageDrafts.length);
      final savedPage = (data['currentPage'] as num?)?.toInt() ?? 0;
      currentPage = savedPage.clamp(0, documentPageCount - 1).toInt();
      final pageData = _pageDrafts[currentPage];
      if (pageData.isNotEmpty) data = pageData;
    }
    _restorePageDraft(data);
  }

  void _restorePageDraft(Map<String, dynamic> data) {
    signaturePlaced = data['signaturePlaced'] == true;
    signatureX = _doubleFromJson(data['signatureX'], signatureX);
    signatureY = _doubleFromJson(data['signatureY'], signatureY);
    signatureScale = _doubleFromJson(data['signatureScale'], signatureScale);
    signatureRotation =
        _doubleFromJson(data['signatureRotation'], signatureRotation);
    final rawStrokes = data['signatureStrokes'];
    if (rawStrokes is List) {
      signatureStrokes = rawStrokes.whereType<Map>().map((raw) {
        final rawPoints = raw['points'];
        final points = rawPoints is List
            ? rawPoints
                .map((point) => _offsetFromJson(point, Offset.zero))
                .toList()
            : <Offset>[];
        return SignatureStroke(
          points: points,
          colorValue: (raw['color'] as num?)?.toInt() ?? 0xFF173B4B,
          width: _doubleFromJson(raw['width'], 3),
        );
      }).toList();
    }

    textPlaced = data['textPlaced'] == true;
    textValue = data['textValue'] as String? ?? textValue;
    textColor = _colorFromJson(data['textColor'], textColor);
    textFontSize = _doubleFromJson(data['textFontSize'], textFontSize);
    textFontFamily = _fontFromJson(data['textFontFamily'], textFontFamily);
    textPosition = _offsetFromJson(data['textPosition'], textPosition);
    textScale = _doubleFromJson(data['textScale'], textScale);
    textRotation = _doubleFromJson(data['textRotation'], textRotation);

    datePlaced = data['datePlaced'] == true;
    final restoredDate =
        DateTime.tryParse(data['selectedDate'] as String? ?? '');
    if (restoredDate != null) selectedDate = restoredDate;
    dateColor = _colorFromJson(data['dateColor'], dateColor);
    dateFontSize = _doubleFromJson(data['dateFontSize'], dateFontSize);
    dateFontFamily = _fontFromJson(data['dateFontFamily'], dateFontFamily);
    datePosition = _offsetFromJson(data['datePosition'], datePosition);
    dateScale = _doubleFromJson(data['dateScale'], dateScale);
    dateRotation = _doubleFromJson(data['dateRotation'], dateRotation);

    checkboxPlaced = data['checkboxPlaced'] == true;
    checkboxValue = data['checkboxValue'] == true;
    checkboxColor = _colorFromJson(data['checkboxColor'], checkboxColor);
    checkboxPosition =
        _offsetFromJson(data['checkboxPosition'], checkboxPosition);
    checkboxScale = _doubleFromJson(data['checkboxScale'], checkboxScale);
    checkboxRotation =
        _doubleFromJson(data['checkboxRotation'], checkboxRotation);

    stampPlaced = data['stampPlaced'] == true;
    stampText = data['stampText'] as String? ?? stampText;
    stampColor = _colorFromJson(data['stampColor'], stampColor);
    stampFontFamily = _fontFromJson(data['stampFontFamily'], stampFontFamily);
    stampImagePath = data['stampImagePath'] as String?;
    stampPosition = _offsetFromJson(data['stampPosition'], stampPosition);
    stampScale = _doubleFromJson(data['stampScale'], stampScale);
    stampRotation = _doubleFromJson(data['stampRotation'], stampRotation);
  }

  Future<void> _saveDraftAndClose() async {
    await _saveDraft();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _showExportActions(BuildContext context) async {
    final action = await showModalBottomSheet<_ExportAction>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Text(
                  'What would you like to do?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE5F4F5),
                  foregroundColor: Color(0xFF0E7490),
                  child: Icon(Icons.ios_share_outlined),
                ),
                title: const Text('Share PDF'),
                subtitle: const Text('Open the share sheet for this PDF'),
                onTap: () => Navigator.pop(sheetContext, _ExportAction.share),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF0F4F5),
                  foregroundColor: Color(0xFF17212B),
                  child: Icon(Icons.download_outlined),
                ),
                title: const Text('Export as PDF'),
                subtitle: const Text('Choose where to save the PDF'),
                onTap: () => Navigator.pop(sheetContext, _ExportAction.export),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    await _showExportGate(context, share: action == _ExportAction.share);
  }

  Future<void> _showExportGate(
    BuildContext context, {
    required bool share,
  }) async {
    await _saveDraft();
    if (!mounted) return;
    if (kDebugMode) {
      documentStatus = DocumentStatus.completed;
      await _persistDocument(DocumentStatus.completed);
      final exportError = await _exportDocument(share: share);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            exportError ??
                (share
                    ? 'Debug PDF shared and saved to Completed for testing.'
                    : 'Debug PDF exported and saved to Completed for testing.'),
          ),
        ),
      );
      return;
    }
    final completed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => const _ExportPaywall(),
    );
    if (completed == true && mounted) {
      documentStatus = DocumentStatus.completed;
      await _persistDocument(DocumentStatus.completed);
      final exportError = await _exportDocument(share: share);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            exportError ??
                (share
                    ? 'Document completed, saved to Completed, and ready to share.'
                    : 'Document completed and exported to PDF.'),
          ),
        ),
      );
    }
  }

  Future<String?> _exportDocument({required bool share}) async {
    OverlayEntry? progress;
    void hideProgress() {
      final entry = progress;
      if (entry == null) return;
      progress = null;
      entry.remove();
      entry.dispose();
    }

    try {
      progress = OverlayEntry(
        builder: (_) => Stack(
          children: [
            const ModalBarrier(
              dismissible: false,
              color: Color(0x990F2630),
            ),
            Center(
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: 232,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        const Text(
                          'Preparing PDF',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          share
                              ? 'The share sheet will open shortly.'
                              : 'Choose a save location when it opens.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF62707B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      Overlay.of(context).insert(progress!);
      _commitActiveTransforms();
      await WidgetsBinding.instance.endOfFrame;
      // Persist the exact page state used for rendering before awaiting file
      // IO so the completed record and exported PDF cannot disagree.
      await _persistDocument(DocumentStatus.completed);
      // Do not export the Flutter preview itself. Screen-security plugins and
      // platform surfaces can make a RepaintBoundary blank even though it is
      // visible on screen. Read the original scan/import and compose the
      // annotations into a new PDF instead.
      final sourcePages = await _loadSourcePagePngs();
      if (sourcePages.isEmpty) {
        return 'Document completed, but the scanned pages could not be read.';
      }

      final currentPageData = _buildPageDraftData();
      final pageDrafts = List<Map<String, dynamic>>.generate(
        sourcePages.length,
        (index) {
          if (index == currentPage) return currentPageData;
          if (index < _pageDrafts.length && _pageDrafts[index].isNotEmpty) {
            return _pageDrafts[index];
          }
          return <String, dynamic>{};
        },
      );
      final pdfDocument = pw.Document();
      for (var index = 0; index < sourcePages.length; index++) {
        final sourcePage = sourcePages[index];
        final draft = pageDrafts[index];
        final flattenedPage = await _renderExportPage(sourcePage, draft);
        final pageFormat = pdf.PdfPageFormat(
          sourcePage.width.toDouble() * 72 / 144,
          sourcePage.height.toDouble() * 72 / 144,
        );
        pdfDocument.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Image(
              pw.MemoryImage(flattenedPage),
              width: pageFormat.width,
              height: pageFormat.height,
              fit: pw.BoxFit.fill,
            ),
          ),
        );
      }
      final pdfBytes = await pdfDocument.save();
      final directory = await getApplicationDocumentsDirectory();
      final safeName = widget.title
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      final fileName = '${safeName.isEmpty ? 'signed_document' : safeName}.pdf';
      final output = File('${directory.path}/$fileName');
      await output.writeAsBytes(pdfBytes, flush: true);
      exportedPath = output.path;
      await _persistDocument(DocumentStatus.completed);

      // On Android and iOS this opens the system document picker and writes
      // the bytes into the location chosen by the user. The private copy above
      // remains as a recovery copy for drafts and devices without a picker.
      String? savedPath;
      try {
        if (!share) {
          savedPath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save signed PDF',
            fileName: fileName,
            type: FileType.custom,
            allowedExtensions: ['pdf'],
            bytes: pdfBytes,
          );
          if (savedPath != null &&
              savedPath.isNotEmpty &&
              !savedPath.startsWith('content://')) {
            final savedFile = File(savedPath);
            if (!await savedFile.exists()) {
              await savedFile.writeAsBytes(pdfBytes, flush: true);
            }
          }
        }
      } catch (_) {
        // Sharing and the private recovery copy still work if the user cancels
        // or a platform does not implement a save picker.
      }
      if (share) {
        await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      }
      hideProgress();
      if (mounted && exportedPath != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExportedPdfViewerScreen(
              title: widget.title,
              path: exportedPath!,
            ),
          ),
        );
      }
      if (!share) {
        return savedPath == null || savedPath.isEmpty
            ? 'PDF exported and saved in the app.'
            : 'PDF exported successfully.';
      }
      return savedPath == null || savedPath.isEmpty
          ? 'PDF saved in the app and ready to share.'
          : 'PDF saved and ready to share.';
    } catch (error) {
      return 'Export failed: ${error.toString().replaceFirst('Exception: ', '')}';
    } finally {
      hideProgress();
    }
  }

  Future<Uint8List> _renderExportPage(
    _ExportPageImage sourcePage,
    Map<String, dynamic> draft,
  ) async {
    final codec = await ui.instantiateImageCodec(sourcePage.bytes);
    final frame = await codec.getNextFrame();
    final sourceImage = frame.image;
    final pageSize = Size(
      sourcePage.width.toDouble(),
      sourcePage.height.toDouble(),
    );
    // Preview annotations are positioned in the preview Stack's coordinate
    // space. Its document is BoxFit.contain inside a 12px inset. Map that
    // exact page rectangle to source pixels; never letterbox twice in PDF.
    final previewSize =
        _documentPreviewKey.currentContext?.size ?? const Size(360, 640);
    final previewInner = Size(
      math.max(1, previewSize.width - 24),
      math.max(1, previewSize.height - 24),
    );
    final sourceAspect = pageSize.width / pageSize.height;
    final previewAspect = previewInner.width / previewInner.height;
    final previewPageSize = previewAspect > sourceAspect
        ? Size(previewInner.height * sourceAspect, previewInner.height)
        : Size(previewInner.width, previewInner.width / sourceAspect);
    final previewPageRect = Rect.fromLTWH(
      12 + (previewInner.width - previewPageSize.width) / 2,
      12 + (previewInner.height - previewPageSize.height) / 2,
      previewPageSize.width,
      previewPageSize.height,
    );
    final scaleX = pageSize.width / previewPageRect.width;
    final scaleY = pageSize.height / previewPageRect.height;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & pageSize);
    canvas.drawImageRect(
      sourceImage,
      Rect.fromLTWH(
          0, 0, sourceImage.width.toDouble(), sourceImage.height.toDouble()),
      Offset.zero & pageSize,
      Paint()..filterQuality = FilterQuality.high,
    );

    // Paint annotations in the editor's coordinate system. This applies the
    // page crop and scaling once, after each field has used its own pivot.
    canvas.save();
    canvas.scale(scaleX, scaleY);
    canvas.translate(-previewPageRect.left, -previewPageRect.top);

    Offset fieldPosition(dynamic value) =>
        value is Map ? _offsetFromJson(value, Offset.zero) : Offset.zero;

    double fieldScale(dynamic value) =>
        ((value as num?)?.toDouble() ?? 1).clamp(.5, 3).toDouble();
    double fieldRotation(dynamic value) => (value as num?)?.toDouble() ?? 0;
    void drawField({
      required Offset position,
      required Size size,
      required double scale,
      required double rotation,
      required void Function(Canvas canvas, Size size) paint,
    }) {
      // _MovableField's 112px hit area is outside both transforms. The
      // rotated/scaled child is the content plus its 6px padding on each side.
      final containerSize = Size(size.width + 12, size.height + 12);
      final center = position + containerSize.center(Offset.zero);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation);
      canvas.scale(scale);
      canvas.translate(-containerSize.width / 2, -containerSize.height / 2);
      canvas.translate(6, 6);
      paint(canvas, size);
      canvas.restore();
    }

    if (draft['signaturePlaced'] == true) {
      final strokes = _signatureStrokesFromDraft(draft['signatureStrokes']);
      if (strokes.isNotEmpty) {
        final painter = _SignaturePainter(
          strokes,
          showGuide: false,
          fitToCanvas: true,
        );
        drawField(
          position: fieldPosition({
            'x': draft['signatureX'],
            'y': draft['signatureY'],
          }),
          size: const Size(188, 74),
          scale: fieldScale(draft['signatureScale']),
          rotation: fieldRotation(draft['signatureRotation']),
          paint: painter.paint,
        );
      }
    }

    void drawTextField({
      required String text,
      required dynamic rawPosition,
      required dynamic rawFontSize,
      required dynamic rawFontFamily,
      required dynamic rawColor,
      required dynamic rawScale,
      required dynamic rawRotation,
    }) {
      if (text.isEmpty) return;
      final fontSize = (rawFontSize as num?)?.toDouble() ?? 14;
      final color = Color((rawColor as num?)?.toInt() ?? 0xFF173B4B);
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: _annotationTextStyle(
              rawFontFamily as String? ?? 'Inter', fontSize, color),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final fieldSize = Size(painter.width, painter.height);
      drawField(
        position: fieldPosition(rawPosition),
        size: fieldSize,
        scale: fieldScale(rawScale),
        rotation: fieldRotation(rawRotation),
        paint: (canvas, _) => painter.paint(canvas, Offset.zero),
      );
    }

    if (draft['textPlaced'] == true) {
      drawTextField(
        text: draft['textValue'] as String? ?? '',
        rawPosition: draft['textPosition'],
        rawFontSize: draft['textFontSize'],
        rawFontFamily: draft['textFontFamily'],
        rawColor: draft['textColor'],
        rawScale: draft['textScale'],
        rawRotation: draft['textRotation'],
      );
    }
    if (draft['datePlaced'] == true) {
      final date = DateTime.tryParse(draft['selectedDate'] as String? ?? '');
      drawTextField(
        text: date == null
            ? _formattedDate(DateTime.now())
            : _formattedDate(date),
        rawPosition: draft['datePosition'],
        rawFontSize: draft['dateFontSize'],
        rawFontFamily: draft['dateFontFamily'],
        rawColor: draft['dateColor'],
        rawScale: draft['dateScale'],
        rawRotation: draft['dateRotation'],
      );
    }

    if (draft['checkboxPlaced'] == true) {
      final checkboxSize = 25.0;
      final position = fieldPosition(draft['checkboxPosition']);
      final color =
          Color((draft['checkboxColor'] as num?)?.toInt() ?? 0xFF173B4B);
      // Draw the Material icon as a vector path with Flutter's matching glyph.
      final iconData = draft['checkboxValue'] == true
          ? Icons.check_box
          : Icons.check_box_outline_blank;
      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(iconData.codePoint),
          style: TextStyle(
            fontSize: checkboxSize,
            fontFamily: iconData.fontFamily,
            package: iconData.fontPackage,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      drawField(
        position: position,
        size: const Size(25, 25),
        scale: fieldScale(draft['checkboxScale']),
        rotation: fieldRotation(draft['checkboxRotation']),
        paint: (canvas, _) => iconPainter.paint(canvas, Offset.zero),
      );
    }

    if (draft['stampPlaced'] == true) {
      final stampSize = stampImageBytes != null || stampImagePath != null
          ? const Size(180, 100)
          : const Size(150, 54);
      final rawPosition = draft['stampPosition'];
      if (stampImageBytes != null || stampImagePath != null) {
        ui.Image? stamp;
        if (stampImageBytes != null) {
          final stampCodec = await ui.instantiateImageCodec(stampImageBytes!);
          stamp = (await stampCodec.getNextFrame()).image;
        } else {
          final path = draft['stampImagePath'] as String?;
          if (path != null && path.isNotEmpty) {
            final file = File(path);
            if (await file.exists()) {
              final stampCodec =
                  await ui.instantiateImageCodec(await file.readAsBytes());
              stamp = (await stampCodec.getNextFrame()).image;
            }
          }
        }
        if (stamp != null) {
          drawField(
            position: fieldPosition(rawPosition),
            size: stampSize,
            scale: fieldScale(draft['stampScale']),
            rotation: fieldRotation(draft['stampRotation']),
            paint: (canvas, size) => canvas.drawImageRect(
              stamp!,
              Rect.fromLTWH(
                  0, 0, stamp!.width.toDouble(), stamp!.height.toDouble()),
              Offset.zero & size,
              Paint()..filterQuality = FilterQuality.high,
            ),
          );
        }
      } else {
        final color =
            Color((draft['stampColor'] as num?)?.toInt() ?? 0xFF0E7490);
        final fontFamily = draft['stampFontFamily'] as String? ?? 'Roboto Slab';
        final text = TextPainter(
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          text: TextSpan(
            text: draft['stampText'] as String? ?? 'APPROVED',
            style: _annotationTextStyle(fontFamily, 11, color,
                fontWeight: FontWeight.w800, letterSpacing: 1.05),
          ),
        )..layout();
        final iconData = Icons.verified_outlined;
        final icon = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: String.fromCharCode(iconData.codePoint),
            style: TextStyle(
              inherit: false,
              fontSize: 15,
              fontFamily: iconData.fontFamily,
              package: iconData.fontPackage,
              color: color,
            ),
          ),
        )..layout();
        final contentWidth = 15 + 6 + text.width;
        final contentHeight = math.max(15, text.height);
        final contentScale =
            math.min(1.0, math.min(127.2 / contentWidth, 39.2 / contentHeight));
        drawField(
          position: fieldPosition(rawPosition),
          size: stampSize,
          scale: fieldScale(draft['stampScale']),
          rotation: fieldRotation(draft['stampRotation']),
          paint: (canvas, size) {
            final bounds = Offset.zero & size;
            canvas.drawRRect(
              RRect.fromRectAndRadius(bounds, const Radius.circular(4)),
              Paint()
                ..color = color
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.4,
            );
            canvas.save();
            canvas.translate(
              (size.width - contentWidth * contentScale) / 2,
              (size.height - contentHeight * contentScale) / 2,
            );
            canvas.scale(contentScale);
            icon.paint(canvas, Offset(0, (contentHeight - icon.height) / 2));
            text.paint(canvas, Offset(21, (contentHeight - text.height) / 2));
            canvas.restore();
          },
        );
      }
    }

    canvas.restore();

    final picture = recorder.endRecording();
    final image = await picture.toImage(sourcePage.width, sourcePage.height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    sourceImage.dispose();
    image.dispose();
    codec.dispose();
    if (byteData == null) {
      throw StateError('Could not render the completed page.');
    }
    return byteData.buffer.asUint8List();
  }

  Future<List<_ExportPageImage>> _loadSourcePagePngs() async {
    final path = widget.sourcePath;
    if (path == null || path.isEmpty) return <_ExportPageImage>[];
    final file = File(path);
    if (!await file.exists()) return <_ExportPageImage>[];
    if (path.toLowerCase().endsWith('.pdf')) {
      final sourceBytes = await file.readAsBytes();
      final pages = <_ExportPageImage>[];
      await for (final raster in Printing.raster(sourceBytes, dpi: 144)) {
        pages.add(
          _ExportPageImage(
            bytes: await raster.toPng(),
            width: raster.width,
            height: raster.height,
          ),
        );
      }
      return pages;
    }
    final imageBytes = await file.readAsBytes();
    if (imageBytes.isEmpty) return <_ExportPageImage>[];
    final decoded =
        image_lib.bakeOrientation(image_lib.decodeImage(imageBytes)!);
    if (decoded == null) return <_ExportPageImage>[];
    final normalizedBytes = Uint8List.fromList(image_lib.encodePng(decoded));
    return <_ExportPageImage>[
      _ExportPageImage(
        bytes: normalizedBytes,
        width: decoded.width,
        height: decoded.height,
      ),
    ];
  }

  List<SignatureStroke> _signatureStrokesFromDraft(dynamic value) {
    if (value is! List) return <SignatureStroke>[];
    return value.whereType<Map>().map((raw) {
      final points = raw['points'] is List
          ? (raw['points'] as List)
              .map((point) => _offsetFromJson(point, Offset.zero))
              .toList()
          : <Offset>[];
      return SignatureStroke(
        points: points,
        colorValue: (raw['color'] as num?)?.toInt() ?? 0xFF173B4B,
        width: _doubleFromJson(raw['width'], 3),
      );
    }).toList();
  }

  Future<void> _saveDraft() async {
    await _persistDocument(
      documentStatus == DocumentStatus.completed
          ? DocumentStatus.completed
          : DocumentStatus.draft,
    );
  }

  Future<void> _persistDocument(DocumentStatus status) async {
    final now = DateTime.now();
    await documentStore.saveDocument(
      DocumentRecord(
        id: draftId,
        name: widget.title,
        sourcePath: widget.sourcePath,
        exportedPath: exportedPath,
        pageCount: documentPageCount,
        createdAt: draftCreatedAt,
        updatedAt: now,
        status: status,
        draftData: _buildDraftData(),
      ),
    );
  }

  Future<void> _closeWorkspace() async {
    await _saveDraft();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _showSignatureActions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Replace signature'),
              onTap: () => Navigator.pop(sheetContext, 'replace'),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Color(0xFFB23A3A),
              ),
              title: const Text('Delete signature'),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'delete') {
      setState(() {
        signaturePlaced = false;
        signatureStrokes = <SignatureStroke>[];
      });
    } else if (action == 'replace') {
      _openSignatureCreator(context);
    }
  }

  void _openSignatureCreator(BuildContext context) {
    Navigator.of(context)
        .push<List<SignatureStroke>>(
      MaterialPageRoute(builder: (_) => const SignatureScreen()),
    )
        .then((saved) {
      if (saved != null && saved.isNotEmpty && mounted) {
        setState(() {
          signatureStrokes = saved.map((stroke) => stroke.copy()).toList();
          signaturePlaced = true;
          selectedField = _EditorField.signature;
        });
      }
    });
  }

  Future<void> _addText() async {
    final value = await _showTextEditor();
    if (!mounted || value == null || value.trim().isEmpty) return;
    setState(() {
      textValue = value.trim();
      textPlaced = true;
      selectedField = _EditorField.text;
    });
  }

  Future<void> _editText() async {
    final value = await _showTextEditor(initialValue: textValue);
    if (!mounted || value == null || value.trim().isEmpty) return;
    setState(() => textValue = value.trim());
  }

  Future<String?> _showTextEditor({String initialValue = ''}) async {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _TextEditorScreen(initialValue: initialValue),
      ),
    );
  }

  Future<void> _addDate() async => _chooseDate();

  Future<void> _chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || picked == null) return;
    setState(() {
      selectedDate = picked;
      datePlaced = true;
      selectedField = _EditorField.date;
    });
  }

  Future<void> _addStamp() async => _chooseStamp();

  Future<void> _chooseStamp() async {
    final option = await showModalBottomSheet<_StampOption>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose a stamp',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              for (final item in _stampOptions)
                ListTile(
                  leading: Icon(Icons.verified_outlined, color: item.color),
                  title: Text(item.label),
                  onTap: () => Navigator.pop(sheetContext, item),
                ),
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Upload transparent stamp image'),
                subtitle: const Text('PNG or WebP keeps the background clear'),
                onTap: () => Navigator.pop(
                  sheetContext,
                  const _StampOption.custom(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || option == null) return;
    if (option.isCustom) {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'webp'],
        withData: true,
      );
      if (!mounted || picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      if (file.bytes == null && (file.path == null || file.path!.isEmpty)) {
        return;
      }
      final storedPath = await _storeStampImage(file);
      setState(() {
        stampImageBytes = storedPath == null ? file.bytes : null;
        stampImagePath = storedPath ?? file.path;
        stampPlaced = true;
        selectedField = _EditorField.stamp;
      });
      return;
    }
    setState(() {
      stampText = option.label;
      stampColor = option.color;
      stampImageBytes = null;
      stampImagePath = null;
      stampPlaced = true;
      selectedField = _EditorField.stamp;
    });
  }

  Future<String?> _storeStampImage(PlatformFile file) async {
    try {
      final documents = await getApplicationDocumentsDirectory();
      final directory = Directory('${documents.path}/stamp_assets');
      await directory.create(recursive: true);
      final extension = (file.extension ?? 'png').toLowerCase();
      final target = File(
        '${directory.path}/$draftId-${DateTime.now().millisecondsSinceEpoch}.$extension',
      );
      if (file.path != null && file.path!.isNotEmpty) {
        await File(file.path!).copy(target.path);
      } else if (file.bytes != null) {
        await target.writeAsBytes(file.bytes!, flush: true);
      } else {
        return null;
      }
      return target.path;
    } catch (_) {
      return null;
    }
  }

  String _formattedDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }
}

class _MovableField extends StatefulWidget {
  final Offset position;
  final Widget child;
  final double scale;
  final double rotation;
  final bool selected;
  final ValueChanged<Offset>? onMoved;
  final ValueChanged<_FieldTransform>? onTransform;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  const _MovableField({
    super.key,
    required this.position,
    required this.child,
    this.scale = 1,
    this.rotation = 0,
    this.selected = false,
    this.onMoved,
    this.onTransform,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
  });

  @override
  State<_MovableField> createState() => _MovableFieldState();
}

class _MovableFieldState extends State<_MovableField> {
  static const double _gestureHitSlop = 24;
  static const double _selectedGestureSize = 112;
  static const double _unselectedGestureSize = 48;
  late Offset _livePosition;
  late double _liveScale;
  late double _liveRotation;
  bool _isTransforming = false;
  double gestureStartScale = 1;
  double gestureStartRotation = 0;
  Offset gestureStartPosition = Offset.zero;
  Offset gestureStartFocalPoint = Offset.zero;
  Offset gestureStartCenterGlobal = Offset.zero;
  final GlobalKey _contentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(covariant _MovableField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isTransforming) _syncFromWidget();
  }

  void _syncFromWidget() {
    _livePosition = widget.position;
    _liveScale = widget.scale;
    _liveRotation = widget.rotation;
  }

  Offset get _position => _isTransforming ? _livePosition : widget.position;
  double get _scale => _isTransforming ? _liveScale : widget.scale;
  double get _rotation => _isTransforming ? _liveRotation : widget.rotation;

  void _resizeBy(DragUpdateDetails details) {
    widget.onTransform?.call(
      _FieldTransform(
        _position,
        (_scale + (details.delta.dx - details.delta.dy) / 180)
            .clamp(.5, 3.0)
            .toDouble(),
        _rotation,
      ),
    );
  }

  void _rotateBy(DragUpdateDetails details) {
    widget.onTransform?.call(
      _FieldTransform(_position, _scale, _rotation + details.delta.dx * .015),
    );
  }

  void _finishTransform() {
    if (!_isTransforming) return;
    final transform = _FieldTransform(_livePosition, _liveScale, _liveRotation);
    setState(() => _isTransforming = false);
    if (widget.onTransform != null) {
      widget.onTransform!(transform);
    } else {
      widget.onMoved?.call(transform.position);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      // Keep the visible field at the same document position while giving
      // small fields a comfortable touch target for two-finger gestures.
      left: _position.dx - _gestureHitSlop,
      top: _position.dy - _gestureHitSlop,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress,
        onScaleStart: (details) {
          _livePosition = widget.position;
          _liveScale = widget.scale;
          _liveRotation = widget.rotation;
          _isTransforming = true;
          gestureStartPosition = widget.position;
          gestureStartFocalPoint = details.focalPoint;
          gestureStartScale = widget.scale;
          gestureStartRotation = widget.rotation;
          final renderObject = _contentKey.currentContext?.findRenderObject();
          if (renderObject is RenderBox) {
            gestureStartCenterGlobal = renderObject.localToGlobal(
              renderObject.size.center(Offset.zero),
            );
          } else {
            gestureStartCenterGlobal = details.focalPoint;
          }
          widget.onTap?.call();
        },
        onScaleUpdate: (details) {
          final focalOffset = gestureStartCenterGlobal - gestureStartFocalPoint;
          final transformedOffset =
              _rotateOffset(focalOffset, details.rotation) * details.scale;
          final centerDelta =
              details.focalPoint + transformedOffset - gestureStartCenterGlobal;
          final transform = _FieldTransform(
            gestureStartPosition + centerDelta,
            (gestureStartScale * details.scale).clamp(.5, 3.0).toDouble(),
            gestureStartRotation + details.rotation,
          );
          setState(() {
            _livePosition = transform.position;
            _liveScale = transform.scale;
            _liveRotation = transform.rotation;
          });
        },
        onScaleEnd: (_) => _finishTransform(),
        child: Padding(
          // Keep the gesture target unscaled. If this padding is inside the
          // transform, shrinking a field also shrinks the area needed to
          // place the two fingers for the next pinch gesture.
          padding: const EdgeInsets.all(_gestureHitSlop),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const SizedBox(
                width: _selectedGestureSize,
                height: _selectedGestureSize,
              ),
              Transform.rotate(
                alignment: Alignment.center,
                angle: _rotation,
                child: Transform.scale(
                  alignment: Alignment.center,
                  scale: _scale,
                  child: Container(
                    key: _contentKey,
                    padding: const EdgeInsets.all(6),
                    // The selection outline must not add border padding to
                    // the field or move its transform pivot before export.
                    foregroundDecoration: widget.selected
                        ? BoxDecoration(
                            color: Colors.transparent,
                            border: Border.all(
                              color: const Color(0xFF0E7490),
                              width: 1.2,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          )
                        : null,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        RepaintBoundary(child: widget.child),
                        if (widget.selected)
                          const Positioned(
                            right: 0,
                            bottom: 0,
                            child: Icon(
                              Icons.open_with,
                              size: 14,
                              color: Color(0xFF0E7490),
                            ),
                          ),
                        if (widget.selected) ...[
                          Positioned(
                            left: -18,
                            top: -30,
                            child: _TransformHandle(
                              icon: Icons.rotate_right,
                              tooltip: 'Rotate field',
                              onPanUpdate: _rotateBy,
                            ),
                          ),
                          Positioned(
                            right: -18,
                            bottom: -30,
                            child: _TransformHandle(
                              icon: Icons.open_in_full,
                              tooltip: 'Resize field',
                              onPanUpdate: _resizeBy,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransformHandle extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final ValueChanged<DragUpdateDetails> onPanUpdate;
  const _TransformHandle({
    required this.icon,
    required this.tooltip,
    required this.onPanUpdate,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: onPanUpdate,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            color: Colors.transparent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
                border: Border.all(color: const Color(0xFF0E7490), width: 1.2),
              ),
              child: SizedBox(
                width: 25,
                height: 25,
                child: Icon(icon, size: 15, color: const Color(0xFF0E7490)),
              ),
            ),
          ),
        ),
      );
}

class _DocumentField extends StatelessWidget {
  final String label;
  final IconData icon;
  const _DocumentField({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: const Color(0xFF0E7490)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF173B4B)),
          ),
        ],
      );
}

class _AnnotationToolbar extends StatelessWidget {
  final String label;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onScaleDown;
  final VoidCallback onScaleUp;
  final VoidCallback onStyle;
  final VoidCallback onDelete;

  const _AnnotationToolbar({
    required this.label,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onScaleDown,
    required this.onScaleUp,
    required this.onStyle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF5F5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD3E8E8)),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF173B4B),
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            _AnnotationAction(
              icon: Icons.remove,
              tooltip: 'Smaller',
              onPressed: onScaleDown,
            ),
            _AnnotationAction(
              icon: Icons.add,
              tooltip: 'Larger',
              onPressed: onScaleUp,
            ),
            _AnnotationAction(
              icon: Icons.rotate_left,
              tooltip: 'Rotate left',
              onPressed: onRotateLeft,
            ),
            _AnnotationAction(
              icon: Icons.rotate_right,
              tooltip: 'Rotate right',
              onPressed: onRotateRight,
            ),
            _AnnotationAction(
              icon: Icons.tune,
              tooltip: 'Style',
              onPressed: onStyle,
            ),
            _AnnotationAction(
              icon: Icons.delete_outline,
              tooltip: 'Delete',
              color: const Color(0xFFB23A3A),
              onPressed: onDelete,
            ),
          ],
        ),
      );
}

class _AnnotationAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color color;
  const _AnnotationAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = const Color(0xFF0E7490),
  });

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 38, height: 38),
        icon: Icon(icon, size: 19, color: color),
      );
}

class _StyleColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _StyleColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.white : Colors.transparent,
              width: 3,
            ),
            boxShadow: [
              if (selected)
                const BoxShadow(
                  color: Color(0xFF0E7490),
                  blurRadius: 0,
                  spreadRadius: 2,
                ),
            ],
          ),
        ),
      );
}

class _TextEditorScreen extends StatefulWidget {
  final String initialValue;
  const _TextEditorScreen({required this.initialValue});

  @override
  State<_TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<_TextEditorScreen> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(
            widget.initialValue.isEmpty ? 'Add text' : 'Edit text',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
          actions: [
            TextButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, controller.text),
              child: const Text('Done'),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Text on document',
                  style: TextStyle(fontSize: 13, color: Color(0xFF62707B)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Type text for the document',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFD7E0E3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFD7E0E3)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You can move, resize, and rotate it after placing.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF62707B)),
                ),
              ],
            ),
          ),
        ),
      );
}

class _StampField extends StatelessWidget {
  final String text;
  final Color color;
  final String fontFamily;
  const _StampField({
    required this.text,
    required this.color,
    required this.fontFamily,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        height: 54,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.4),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_outlined, size: 15, color: color),
                  const SizedBox(width: 6),
                  Text(
                    text,
                    style: _annotationTextStyle(fontFamily, 11, color,
                        fontWeight: FontWeight.w800, letterSpacing: 1.05),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _StampImageField extends StatelessWidget {
  final Uint8List? bytes;
  final String? path;
  const _StampImageField({this.bytes, this.path});

  @override
  Widget build(BuildContext context) {
    final image = bytes != null
        ? Image.memory(bytes!, fit: BoxFit.contain)
        : Image.file(
            File(path!),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image_outlined,
              size: 36,
              color: Color(0xFFB23A3A),
            ),
          );
    return SizedBox(
      width: 180,
      height: 100,
      child: image,
    );
  }
}

class _StampOption {
  final String label;
  final Color color;
  final bool isCustom;
  const _StampOption(this.label, this.color) : isCustom = false;
  const _StampOption.custom()
      : label = '',
        color = const Color(0xFF0E7490),
        isCustom = true;
}

const _stampOptions = [
  _StampOption('APPROVED', Color(0xFF0E7490)),
  _StampOption('PAID', Color(0xFF2E7D32)),
  _StampOption('REVIEW', Color(0xFF8A6B18)),
  _StampOption('REJECTED', Color(0xFFB23A3A)),
];

const _annotationColors = [
  Color(0xFF173B4B),
  Color(0xFF111827),
  Color(0xFF0E7490),
  Color(0xFF1D4ED8),
  Color(0xFF7C3AED),
  Color(0xFFB23A3A),
  Color(0xFF2E7D32),
];

const _annotationFontFamilies = [
  'Inter',
  'Roboto',
  'Open Sans',
  'Lato',
  'Montserrat',
  'Poppins',
  'Raleway',
  'Merriweather',
  'Playfair Display',
  'Roboto Slab',
  'Oswald',
  'Caveat',
];

enum ScannerMode { scan, importFile }

class ScannerFlow extends StatefulWidget {
  final ScannerMode mode;
  const ScannerFlow({super.key, required this.mode});

  @override
  State<ScannerFlow> createState() => _ScannerFlowState();
}

class _ScannerFlowState extends State<ScannerFlow> {
  final scanner = NativeDocumentScanner();
  bool busy = false;
  String? selectedPath;

  bool get isScan => widget.mode == ScannerMode.scan;

  @override
  Widget build(BuildContext context) {
    final title = isScan ? 'Scan document' : 'Import file';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isScan ? 'Capture a clear document' : 'Choose a document',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                isScan
                    ? 'Place a paper inside the scanner. A green outline means it is detected and will capture automatically when steady; use the shutter for manual capture.'
                    : 'Import a PDF, PNG, or JPG and continue to the signing workspace.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 26),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isScan ? const Color(0xFF173B4B) : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: isScan
                        ? null
                        : Border.all(color: const Color(0xFFE1E8EB)),
                  ),
                  child: isScan
                      ? _ScannerPreview()
                      : _ImportPreview(selectedPath: selectedPath),
                ),
              ),
              const SizedBox(height: 18),
              if (selectedPath != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    selectedPath!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF62707B),
                    ),
                  ),
                ),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: busy ? null : _chooseDocument,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          isScan
                              ? Icons.camera_alt_outlined
                              : Icons.folder_open_outlined,
                        ),
                  label: Text(
                    isScan ? 'Start document scanner' : 'Choose from files',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseDocument() async {
    setState(() => busy = true);
    final path = isScan
        ? await scanner.scanDocument(context)
        : await scanner.importDocument();
    if (!mounted) return;
    setState(() {
      busy = false;
      selectedPath = path;
    });
    if (path != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DocumentWorkspace(
            title: isScan ? 'Scanned document' : 'Imported document',
            sourcePath: path,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isScan
                ? 'Camera scanner is not available yet on this build.'
                : 'File import is not available yet on this build.',
          ),
        ),
      );
    }
  }
}

class _ScannerPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 230,
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF8BD1D0), width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(
                    Icons.document_scanner_outlined,
                    size: 62,
                    color: Color(0xFF8BD1D0),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Your document will be detected automatically',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
      );
}

class _ImportPreview extends StatelessWidget {
  final String? selectedPath;
  const _ImportPreview({required this.selectedPath});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selectedPath == null
                  ? Icons.insert_drive_file_outlined
                  : Icons.check_circle_outline,
              size: 58,
              color: const Color(0xFF0E7490),
            ),
            const SizedBox(height: 16),
            Text(
              selectedPath == null ? 'PDF, PNG, or JPG' : 'File selected',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF33434C),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your file will open in the signing workspace',
              style: TextStyle(color: Color(0xFF62707B)),
            ),
          ],
        ),
      );
}

class _EditorTool extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _EditorTool({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                Icon(icon, size: 23, color: const Color(0xFF50616B)),
                const SizedBox(height: 4),
                Text(
                  label,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF50616B)),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ExportPaywall extends StatefulWidget {
  const _ExportPaywall();
  @override
  State<_ExportPaywall> createState() => _ExportPaywallState();
}

class _ExportPaywallState extends State<_ExportPaywall> {
  final billing = SubscriptionService();
  List<SubscriptionOffer> offers = const [];
  SubscriptionPlan selectedPlan = SubscriptionPlan.yearly;
  bool loading = true;
  bool purchasing = false;
  String? error;

  SubscriptionOffer? get offer {
    for (final candidate in offers) {
      if (candidate.plan == selectedPlan) return candidate;
    }
    return offers.isEmpty ? null : offers.first;
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await billing.initialize(
        onEntitlementChanged: (active) {
          if (active && mounted) Navigator.pop(context, true);
        },
      );
      final loadedOffers = await billing.loadOffers();
      if (!mounted) return;
      setState(() {
        offers = loadedOffers;
        loading = false;
        if (loadedOffers.isEmpty) {
          error = 'The subscription is unavailable right now.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'The App Store could not load the subscription.';
      });
    }
  }

  @override
  void dispose() {
    billing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F4F5),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.lock_outline, color: Color(0xFF0E7490)),
              ),
              const SizedBox(height: 18),
              Text(
                'Your document is ready',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                offer?.hasThreeDayTrial == true
                    ? 'Your draft is saved privately on this device. Start your 3-day free trial to finalize, export, and share it.'
                    : 'Your draft is saved privately on this device. Subscribe to finalize, export, and share it.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF62707B), height: 1.45),
              ),
              const SizedBox(height: 20),
              const _PaywallBenefit(
                icon: Icons.picture_as_pdf_outlined,
                text: 'Finalize and export signed PDFs and images',
              ),
              const _PaywallBenefit(
                icon: Icons.ios_share_outlined,
                text: 'Share documents anywhere',
              ),
              const _PaywallBenefit(
                icon: Icons.all_inclusive,
                text: 'Unlimited document signing',
              ),
              const SizedBox(height: 18),
              if (offers.length > 1) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final candidate in offers)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                    '${candidate.periodLabel} ${candidate.renewalPrice}${candidate.periodSuffix}'),
                                if (candidate.hasThreeDayTrial) ...[
                                  const SizedBox(width: 6),
                                  const Text('3 days free',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ],
                            ),
                            selected: candidate.plan == selectedPlan,
                            onSelected: (_) =>
                                setState(() => selectedPlan = candidate.plan),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    error!,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFFB23A3A)),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed:
                      loading || purchasing || offer == null ? null : _purchase,
                  child: loading || purchasing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(offer?.hasThreeDayTrial == true
                          ? 'Start 3-day free trial'
                          : 'Subscribe ${offer?.periodLabel.toLowerCase() ?? ''}'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                offer?.hasThreeDayTrial == true
                    ? '3 days free, then ${offer!.renewalPrice}${offer!.periodSuffix}. Automatically renews until cancelled.'
                    : offer == null
                        ? 'Price and renewal terms are provided by the App Store.'
                        : '${offer!.renewalPrice}${offer!.periodSuffix}. Automatically renews until cancelled.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Color(0xFF7A878E)),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      );

  Future<void> _purchase() async {
    setState(() {
      purchasing = true;
      error = null;
    });
    final selectedOffer = offer;
    final started = selectedOffer == null
        ? false
        : await billing.purchasePlan(selectedOffer);
    if (!mounted) return;
    if (!started) {
      setState(() {
        purchasing = false;
        error =
            'The subscription is unavailable right now. Please try again later.';
      });
    } else {
      setState(() => purchasing = false);
    }
  }
}

class _PaywallBenefit extends StatelessWidget {
  final IconData icon;
  final String text;
  const _PaywallBenefit({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF0E7490)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 14, color: Color(0xFF33434C)),
              ),
            ),
          ],
        ),
      );
}

class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key});
  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final List<SignatureStroke> strokes = [];
  final List<SignatureStroke> savedStrokes = [];
  SignatureStroke? activeStroke;
  Color brushColor = const Color(0xFF173B4B);
  double brushWidth = 3;

  static const brushColors = [
    Color(0xFF173B4B),
    Color(0xFF111827),
    Color(0xFF0E7490),
    Color(0xFF1D4ED8),
    Color(0xFF7C3AED),
    Color(0xFFB23A3A),
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedSignature();
  }

  Future<void> _loadSavedSignature() async {
    final saved = await SignatureStore().loadSignature();
    if (!mounted || saved.isEmpty) return;
    setState(() => savedStrokes.addAll(saved.map((stroke) => stroke.copy())));
  }

  @override
  Widget build(BuildContext context) {
    final hasSignature = strokes.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create signature',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        actions: [
          TextButton(
            onPressed: hasSignature ? _save : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Draw your signature',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Use your finger or stylus. Adjust the ink before placing it on your document.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (savedStrokes.isNotEmpty) ...[
                const SizedBox(height: 14),
                _SavedSignatureCard(
                  strokes: savedStrokes,
                  onUse: _useSavedSignature,
                  onEdit: _editSavedSignature,
                  onAddNew: _startNewSignature,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Ink',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final color in brushColors)
                            _BrushColorDot(
                              color: color,
                              selected: brushColor == color,
                              onTap: () => _setBrushColor(color),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text(
                    'Thickness',
                    style: TextStyle(fontSize: 12, color: Color(0xFF62707B)),
                  ),
                  Expanded(
                    child: Slider(
                      value: brushWidth,
                      min: 1.5,
                      max: 6,
                      divisions: 9,
                      label: '${brushWidth.toStringAsFixed(1)} px',
                      onChanged: _setBrushWidth,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Undo last stroke',
                    onPressed: hasSignature
                        ? () => setState(() => strokes.removeLast())
                        : null,
                    icon: const Icon(Icons.undo),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFD7E0E3)),
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (details) => setState(() {
                      activeStroke = SignatureStroke(
                        points: [details.localPosition],
                        colorValue: brushColor.value,
                        width: brushWidth,
                      );
                      strokes.add(activeStroke!);
                    }),
                    onPanUpdate: (details) => setState(() {
                      activeStroke?.points.add(details.localPosition);
                    }),
                    onPanEnd: (_) => activeStroke = null,
                    onPanCancel: () => activeStroke = null,
                    child: CustomPaint(
                      painter: _SignaturePainter(strokes),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Transparent signature preview',
                    style: TextStyle(fontSize: 12, color: Color(0xFF62707B)),
                  ),
                  TextButton.icon(
                    onPressed:
                        hasSignature ? () => setState(strokes.clear) : null,
                    icon: const Icon(Icons.refresh, size: 17),
                    label: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: hasSignature ? _save : null,
                  child: const Text('Save signature'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    await SignatureStore().saveSignature(strokes);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signature saved for future documents.')),
    );
    Navigator.pop(context, strokes.map((stroke) => stroke.copy()).toList());
  }

  void _setBrushColor(Color color) {
    setState(() {
      brushColor = color;
      for (final stroke in strokes) {
        stroke.colorValue = color.value;
      }
    });
  }

  void _setBrushWidth(double width) {
    setState(() {
      brushWidth = width;
      for (final stroke in strokes) {
        stroke.width = width;
      }
    });
  }

  void _useSavedSignature() {
    Navigator.pop(
      context,
      savedStrokes.map((stroke) => stroke.copy()).toList(),
    );
  }

  void _editSavedSignature() {
    setState(() {
      strokes
        ..clear()
        ..addAll(savedStrokes.map((stroke) => stroke.copy()));
      final last = savedStrokes.last;
      brushColor = Color(last.colorValue);
      brushWidth = last.width;
    });
  }

  void _startNewSignature() {
    setState(() => strokes.clear());
  }
}

class _SavedSignatureCard extends StatelessWidget {
  final List<SignatureStroke> strokes;
  final VoidCallback onUse;
  final VoidCallback onEdit;
  final VoidCallback onAddNew;
  const _SavedSignatureCard({
    required this.strokes,
    required this.onUse,
    required this.onEdit,
    required this.onAddNew,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF5F5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFB9D9DA)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.verified_outlined,
                  size: 18,
                  color: Color(0xFF0E7490),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Saved signature',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
                  width: 124,
                  height: 44,
                  child: CustomPaint(
                    painter: _SignaturePainter(
                      strokes,
                      showGuide: false,
                      fitToCanvas: true,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                TextButton(onPressed: onEdit, child: const Text('Edit')),
                TextButton(onPressed: onAddNew, child: const Text('Add new')),
                const Spacer(),
                FilledButton.tonal(onPressed: onUse, child: const Text('Use')),
              ],
            ),
          ],
        ),
      );
}

class _BrushColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _BrushColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.white : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                if (selected)
                  const BoxShadow(
                    color: Color(0x550E7490),
                    blurRadius: 0,
                    spreadRadius: 2,
                  ),
              ],
            ),
          ),
        ),
      );
}

class _SignaturePainter extends CustomPainter {
  final List<SignatureStroke> strokes;
  final bool showGuide;
  final bool fitToCanvas;
  _SignaturePainter(
    this.strokes, {
    this.showGuide = true,
    this.fitToCanvas = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final points = strokes.expand((stroke) => stroke.points).toList();
    if (points.isEmpty) {
      if (showGuide) _paintGuide(canvas, size);
      return;
    }

    var scale = 1.0;
    if (fitToCanvas) {
      final minX =
          points.map((point) => point.dx).reduce((a, b) => a < b ? a : b);
      final maxX =
          points.map((point) => point.dx).reduce((a, b) => a > b ? a : b);
      final minY =
          points.map((point) => point.dy).reduce((a, b) => a < b ? a : b);
      final maxY =
          points.map((point) => point.dy).reduce((a, b) => a > b ? a : b);
      final sourceWidth = (maxX - minX).clamp(1.0, double.infinity).toDouble();
      final sourceHeight = (maxY - minY).clamp(1.0, double.infinity).toDouble();
      const padding = 10.0;
      scale = ((size.width - padding * 2) / sourceWidth).clamp(.1, 10.0);
      scale = (scale < (size.height - padding * 2) / sourceHeight
              ? scale
              : (size.height - padding * 2) / sourceHeight)
          .clamp(.1, 10.0);
      final translate = Offset(
        (size.width - sourceWidth * scale) / 2 - minX * scale,
        (size.height - sourceHeight * scale) / 2 - minY * scale,
      );
      canvas.save();
      canvas.translate(translate.dx, translate.dy);
      canvas.scale(scale);
    }

    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final pen = Paint()
        ..color = Color(stroke.colorValue)
        ..strokeWidth =
            fitToCanvas ? (stroke.width / scale).clamp(1.0, 8.0) : stroke.width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      if (stroke.points.length == 1) {
        canvas.drawCircle(
          stroke.points.first,
          pen.strokeWidth / 2,
          Paint()..color = pen.color,
        );
        continue;
      }
      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (var index = 1; index < stroke.points.length - 1; index++) {
        final current = stroke.points[index];
        final next = stroke.points[index + 1];
        final midpoint = Offset(
          (current.dx + next.dx) / 2,
          (current.dy + next.dy) / 2,
        );
        path.quadraticBezierTo(
          current.dx,
          current.dy,
          midpoint.dx,
          midpoint.dy,
        );
      }
      path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
      canvas.drawPath(path, pen);
    }

    if (fitToCanvas) {
      canvas.restore();
    } else if (showGuide) {
      _paintGuide(canvas, size);
    }
  }

  void _paintGuide(Canvas canvas, Size size) {
    final guide = Paint()
      ..color = const Color(0xFFD7E0E3)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(24, size.height * .68),
      Offset(size.width - 24, size.height * .68),
      guide,
    );
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
