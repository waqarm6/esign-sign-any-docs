import 'package:flutter/material.dart';

import 'services/subscription_service.dart';

class StartupPaywallScreen extends StatefulWidget {
  final VoidCallback onContinue;

  const StartupPaywallScreen({super.key, required this.onContinue});

  @override
  State<StartupPaywallScreen> createState() => _StartupPaywallScreenState();
}

class _StartupPaywallScreenState extends State<StartupPaywallScreen> {
  final SubscriptionService _billing = SubscriptionService();
  List<SubscriptionOffer> _offers = const [];
  SubscriptionPlan _selectedPlan = SubscriptionPlan.yearly;
  bool _loading = true;
  bool _busy = false;
  bool _navigated = false;
  String? _message;

  SubscriptionOffer? get _offer {
    for (final offer in _offers) {
      if (offer.plan == _selectedPlan) return offer;
    }
    return _offers.isEmpty ? null : _offers.first;
  }

  void _continue() {
    if (_navigated) return;
    _navigated = true;
    widget.onContinue();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _billing.initialize(onEntitlementChanged: (active) {
        if (active && mounted) _continue();
      });
      final offers = await _billing.loadOffers();
      if (mounted) setState(() => _offers = offers);
    } catch (_) {
      // The app is still usable offline and when a store is unavailable.
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _purchase() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final offer = _offer;
      final started =
          offer == null ? false : await _billing.purchasePlan(offer);
      if (mounted && !started) {
        setState(() => _message =
            'The plan is unavailable right now. Close this screen to use drafts.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'The store could not open. Please try again or close this screen.');
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _billing.restorePurchases();
      if (mounted) {
        setState(() => _message =
            'Restore requested. An active subscription will open your workspace.');
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'Could not restore purchases.');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  void dispose() {
    _billing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF102D3B);
    const teal = Color(0xFF087D82);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 680;
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Image(
                              image: AssetImage(
                                  'assets/secure_signature_icon.png'),
                              width: 26,
                              height: 26,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text('eSign : Sign Any Docs',
                                  style: TextStyle(
                                      color: navy,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                      letterSpacing: -.3)),
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 8 : 14),
                        Stack(
                          children: [
                            _PaywallArtwork(height: compact ? 190 : 242),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                tooltip: 'Close paywall',
                                onPressed: _continue,
                                icon: const Icon(
                                  Icons.close,
                                  color: Color(0xFF69848A),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 14 : 22),
                        const Text('Make every document\nready to go.',
                            style: TextStyle(
                                color: navy,
                                fontSize: 30,
                                height: 1.08,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.1)),
                        const SizedBox(height: 10),
                        const Text(
                          'Create and edit drafts for free. Unlock finished PDFs when you need to send your work.',
                          style: TextStyle(
                              color: Color(0xFF536670),
                              fontSize: 14,
                              height: 1.45),
                        ),
                        SizedBox(height: compact ? 16 : 21),
                        const _Benefit(
                            icon: Icons.picture_as_pdf_outlined,
                            text: 'Export polished, signed PDFs'),
                        const _Benefit(
                            icon: Icons.ios_share_outlined,
                            text: 'Share straight from your phone'),
                        const _Benefit(
                            icon: Icons.all_inclusive,
                            text: 'Sign and complete unlimited documents'),
                        if (_message != null) ...[
                          const SizedBox(height: 10),
                          Text(_message!,
                              style: const TextStyle(
                                  color: Color(0xFF9F3F35), fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE8EEED))),
                  ),
                  child: Column(
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(_offer?.periodLabel ?? 'Subscription plan',
                              style: const TextStyle(
                                  color: navy,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          Text(
                            _loading
                                ? 'Checking price…'
                                : _offer?.renewalPrice ?? 'Store unavailable',
                            style: const TextStyle(
                                color: teal,
                                fontWeight: FontWeight.w800,
                                fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: _busy || _offer == null ? null : _purchase,
                          style: FilledButton.styleFrom(
                            backgroundColor: navy,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text(
                                  _offer?.hasThreeDayTrial == true
                                      ? 'Start 3-day free trial'
                                      : 'Subscribe ${_offer?.periodLabel.toLowerCase() ?? ''}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                        ),
                      ),
                      if (_offers.length > 1) ...[
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final offer in _offers)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                            '${offer.periodLabel} ${offer.renewalPrice}${offer.periodSuffix}'),
                                        if (offer.hasThreeDayTrial) ...[
                                          const SizedBox(width: 6),
                                          const Text('3 days free',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700)),
                                        ],
                                      ],
                                    ),
                                    selected: offer.plan == _selectedPlan,
                                    onSelected: (_) => setState(
                                        () => _selectedPlan = offer.plan),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 3),
                      TextButton(
                          onPressed: _busy ? null : _restore,
                          child: const Text('Restore purchases')),
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => _showPolicy(
                              'Terms of use',
                              'eSign : Sign Any Docs offers automatically renewing subscription plans. Any eligible 3-day free trial converts to the selected plan unless cancelled at least 24 hours before the trial ends. Payment is charged to your App Store account. You can manage or cancel in App Store subscription settings.',
                            ),
                            child: const Text('Terms'),
                          ),
                          TextButton(
                            onPressed: () => _showPolicy(
                              'Privacy policy',
                              'Documents, signatures, and annotation drafts are stored on this device. Camera and file access are used only when you choose to scan or import. Files leave the app only when you explicitly export or share them. Purchase processing is handled by the App Store.',
                            ),
                            child: const Text('Privacy'),
                          ),
                        ],
                      ),
                      Text(
                        _offer?.hasThreeDayTrial == true
                            ? '3 days free, then ${_offer!.renewalPrice}${_offer!.periodSuffix}. Automatically renews until cancelled in your app store.'
                            : _offer == null
                                ? 'Create and edit drafts for free. Subscription terms appear before purchase.'
                                : '${_offer!.renewalPrice}${_offer!.periodSuffix}. Automatically renews until cancelled in your app store.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFF6F7E82),
                            fontSize: 11.5,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showPolicy(String title, String body) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Benefit({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: const Color(0xFFE4F3F1),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 17, color: const Color(0xFF087D82)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF263D47),
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

class _PaywallArtwork extends StatelessWidget {
  final double height;
  const _PaywallArtwork({required this.height});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            color: const Color(0xFFE4F2F1),
            borderRadius: BorderRadius.circular(24)),
        child: LayoutBuilder(
          builder: (context, size) => Stack(
            children: [
              Positioned(
                right: -35,
                top: -76,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Color(0xFFC8E8E6)),
                ),
              ),
              Positioned(
                left: -70,
                bottom: -125,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Color(0xFFD6EBF1)),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Transform.rotate(
                  angle: -.085,
                  child: Container(
                    width: height * .69,
                    height: height * .88,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x240F3E4D),
                              blurRadius: 20,
                              offset: Offset(0, 11)),
                        ]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.description_outlined,
                              size: 22, color: Color(0xFF087D82)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                    color: const Color(0xFFD2E1E3),
                                    borderRadius: BorderRadius.circular(4))),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        for (var i = 0; i < 3; i++) ...[
                          Container(
                            width: i == 2 ? 80 : double.infinity,
                            height: 5,
                            decoration: BoxDecoration(
                                color: const Color(0xFFE1E9EA),
                                borderRadius: BorderRadius.circular(4)),
                          ),
                          const SizedBox(height: 8),
                        ],
                        const Spacer(),
                        const Icon(Icons.draw_outlined,
                            color: Color(0xFF174B65), size: 37),
                        const SizedBox(height: 7),
                        Container(height: 1, color: const Color(0xFFCEE1E3)),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 22,
                top: height * .28,
                child: const _ArtworkChip(
                    icon: Icons.check_circle, label: 'SIGNED'),
              ),
              Positioned(
                left: 17,
                bottom: height * .16,
                child: const _ArtworkChip(
                    icon: Icons.picture_as_pdf_outlined, label: 'PDF READY'),
              ),
            ],
          ),
        ),
      );
}

class _ArtworkChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ArtworkChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Color(0x190F3E4D), blurRadius: 12),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: const Color(0xFF087D82)),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF203D49),
                  letterSpacing: .4)),
        ]),
      );
}
