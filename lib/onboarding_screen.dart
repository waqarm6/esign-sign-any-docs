import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const onboardingCompleteKey = 'esign_doc_pro_onboarding_complete';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;
  bool _finishing = false;

  static const _titles = [
    'From paper to\nready to sign.',
    'Make every detail\nyours.',
    'Finish with\nconfidence.',
  ];
  static const _descriptions = [
    'Capture clean pages automatically, or import the file you already have.',
    'Place your signature, text, dates and stamps exactly where they belong.',
    'Review your document, then export a polished PDF when you are ready.',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(onboardingCompleteKey, true);
      if (mounted) widget.onDone();
    } catch (_) {
      if (!mounted) return;
      setState(() => _finishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not save your introduction progress.')),
      );
    }
  }

  void _next() {
    if (_page == 2) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF173B4B);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            children: [
              SizedBox(
                height: 52,
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: ink,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(11)),
                        child: Image.asset(
                          'assets/secure_signature_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('eSign : Sign Any Docs',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: ink)),
                    ),
                    TextButton(
                      onPressed: _finishing ? null : _finish,
                      child: const Text('Skip'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _titles.length,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemBuilder: (context, index) => _IntroPage(
                    index: index,
                    title: _titles[index],
                    description: _descriptions[index],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    '0${_page + 1}  /  03',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: ink,
                    ),
                  ),
                  const Spacer(),
                  ...List.generate(
                    3,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.only(left: 6),
                      width: index == _page ? 26 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: index == _page
                            ? const Color(0xFF0E7490)
                            : const Color(0xFFCCD9DC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _finishing ? null : _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: ink,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _finishing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_page == 2 ? 'Start creating' : 'Continue',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 19),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _page == 2
                    ? 'Draft for free. Export requires a trial or subscription.'
                    : 'Drafts stay on your device.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF50616B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  final int index;
  final String title;
  final String description;

  const _IntroPage({
    required this.index,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 500;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: math.max(220, constraints.maxHeight - 180),
                  child: Semantics(
                    label: switch (index) {
                      0 => 'Document captured inside a scanner frame',
                      1 => 'Document with a placed signature and date',
                      _ => 'Completed PDF ready to share',
                    },
                    image: true,
                    child: ExcludeSemantics(
                      child: _IntroArtwork(index: index),
                    ),
                  ),
                ),
                SizedBox(height: compact ? 16 : 28),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: compact ? 28 : 32,
                    height: 1.08,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                    color: const Color(0xFF17212B),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: Color(0xFF50616B),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _IntroArtwork extends StatefulWidget {
  final int index;
  const _IntroArtwork({required this.index});

  @override
  State<_IntroArtwork> createState() => _IntroArtworkState();
}

class _IntroArtworkState extends State<_IntroArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    if (widget.index == 1) {
      _motion.forward();
    } else {
      _motion.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = widget.index == 1 ? 1 : .5;
    } else if (!_motion.isAnimating) {
      if (widget.index == 1) {
        if (_motion.value < 1) _motion.forward();
      } else {
        _motion.repeat();
      }
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _motion,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final index = widget.index;
            final dark = index == 2;
            final float = math.sin(_motion.value * math.pi * 2) * 5;
            final phoneWidth = math.min(
                220.0,
                math.min(constraints.maxWidth * .62,
                    constraints.maxHeight * .86 / 1.65));
            final phoneHeight = phoneWidth * 1.65;
            return ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color:
                      dark ? const Color(0xFF173B4B) : const Color(0xFFE7F3F2),
                  image: dark
                      ? null
                      : const DecorationImage(
                          image: AssetImage(
                              'assets/onboarding/paper_backdrop.png'),
                          fit: BoxFit.cover,
                        ),
                ),
                child: Stack(
                  children: [
                    if (dark) ...[
                      const Positioned(
                        top: -66,
                        right: -54,
                        child: _BackdropCircle(dark: true, size: 200),
                      ),
                      const Positioned(
                        bottom: -92,
                        left: -56,
                        child: _BackdropCircle(dark: true, size: 220),
                      ),
                    ],
                    Center(
                      child: Transform.translate(
                        offset: Offset(0, float),
                        child: Transform.rotate(
                          angle: index == 0 ? -.10 : .08,
                          child: _PhoneScene(
                            index: index,
                            width: phoneWidth,
                            height: phoneHeight,
                            progress: _motion.value,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      top: math.max(12, constraints.maxHeight * .15),
                      child: Transform.translate(
                        offset: Offset(0, -float * .6),
                        child: _FloatingCard(
                          icon: index == 0
                              ? Icons.file_upload_outlined
                              : index == 1
                                  ? Icons.today_outlined
                                  : Icons.picture_as_pdf_outlined,
                          label: index == 0
                              ? 'IMPORT'
                              : index == 1
                                  ? 'DATE'
                                  : 'PDF',
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: math.max(22, constraints.maxHeight * .26),
                      child: Transform.translate(
                        offset: Offset(0, float * .7),
                        child: _FloatingCard(
                          icon: index == 0
                              ? Icons.crop_free_outlined
                              : index == 1
                                  ? Icons.draw_outlined
                                  : Icons.ios_share_outlined,
                          label: index == 0
                              ? 'SCAN'
                              : index == 1
                                  ? 'SIGN'
                                  : 'SHARE',
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      bottom: 16,
                      child: _ArtworkBadge(
                        icon: index == 0
                            ? Icons.check_circle_outline
                            : index == 1
                                ? Icons.edit_outlined
                                : Icons.lock_outline,
                        text: index == 0
                            ? 'Edges detected'
                            : index == 1
                                ? (_motion.value < .63
                                    ? 'Adding signature'
                                    : 'Signature placed')
                                : 'Saved privately',
                        dark: dark,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
}

class _BackdropCircle extends StatelessWidget {
  final bool dark;
  final double size;
  const _BackdropCircle({required this.dark, required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: dark ? .05 : .32),
        ),
      );
}

class _PhoneScene extends StatelessWidget {
  final int index;
  final double width;
  final double height;
  final double progress;

  const _PhoneScene({
    required this.index,
    required this.width,
    required this.height,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF102735),
          borderRadius: BorderRadius.circular(33),
          border: Border.all(color: const Color(0xFF3C6271), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x350F3444),
              blurRadius: 26,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Container(
            color: const Color(0xFFF5F9FA),
            child: Column(
              children: [
                SizedBox(
                  height: 22,
                  child: Center(
                    child: Container(
                      width: 48,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF102735),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    index == 0
                        ? 'Scan document'
                        : index == 1
                            ? 'Add signature'
                            : 'PDF ready',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF173B4B),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        FittedBox(
                          fit: BoxFit.contain,
                          child: _DocumentSheet(
                            index: index,
                            width: 232,
                            height: 294,
                            signatureProgress: index == 1
                                ? Curves.easeInOut.transform(
                                    (progress * 1.6).clamp(0, 1).toDouble())
                                : 1,
                          ),
                        ),
                        if (index == 0)
                          Center(
                            child: CustomPaint(
                              size: Size(width * .69, height * .59),
                              painter: _ScanCornersPainter(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                  height: 22,
                  decoration: BoxDecoration(
                    color: index == 2
                        ? const Color(0xFFDAF3E9)
                        : const Color(0xFFDAEFED),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Center(
                    child: Text(
                      index == 0
                          ? 'Capture'
                          : index == 1
                              ? 'Place signature'
                              : 'Export as PDF',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF176A51),
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

class _FloatingCard extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FloatingCard({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        width: 70,
        height: 78,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Color(0x200F3444), blurRadius: 18, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 25, color: const Color(0xFF0E7490)),
            Text(label,
                style: const TextStyle(
                    fontSize: 9,
                    letterSpacing: .5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF173B4B))),
          ],
        ),
      );
}

class _DocumentSheet extends StatelessWidget {
  final int index;
  final double width;
  final double height;
  final double signatureProgress;

  const _DocumentSheet({
    required this.index,
    required this.width,
    required this.height,
    required this.signatureProgress,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x250F3444),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDAEFED),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Icon(Icons.description_outlined,
                      size: 13, color: Color(0xFF0E7490)),
                ),
                const SizedBox(width: 7),
                const Text('DOCUMENT',
                    style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF50616B))),
                const Spacer(),
                if (index == 2)
                  const Text('PDF',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB23A3A))),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 8,
              width: width * .56,
              decoration: BoxDecoration(
                color: const Color(0xFF173B4B),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(
              4,
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FractionallySizedBox(
                  widthFactor: line == 3
                      ? .58
                      : line == 1
                          ? .83
                          : 1,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCE6E8),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            if (index != 0) ...[
              if (index == 1)
                const Text('SIGNED BY',
                    style: TextStyle(
                        fontSize: 8,
                        letterSpacing: 1,
                        color: Color(0xFF6E7B82))),
              SizedBox(
                height: 36,
                width: width * .62,
                child: CustomPaint(
                    painter:
                        _SignatureMarkPainter(progress: signatureProgress)),
              ),
              const Divider(height: 6, color: Color(0xFFB9C9CE)),
              const SizedBox(height: 4),
              Text(index == 1 ? 'Signature · 01 Oct 2026' : 'Signed and ready',
                  style:
                      const TextStyle(fontSize: 9, color: Color(0xFF50616B))),
            ] else ...[
              const Divider(color: Color(0xFFCDDADD)),
              const SizedBox(height: 4),
              const Text('Ready for review',
                  style: TextStyle(fontSize: 9, color: Color(0xFF50616B))),
            ],
          ],
        ),
      );
}

class _ArtworkBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool dark;
  const _ArtworkBadge(
      {required this.icon, required this.text, required this.dark});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color: Color(0x180F3444), blurRadius: 14, offset: Offset(0, 5)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 17,
                color:
                    dark ? const Color(0xFF176A51) : const Color(0xFF0E7490)),
            const SizedBox(width: 7),
            Text(text,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF173B4B))),
          ],
        ),
      );
}

class _ScanCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0E9478)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const arm = 25.0;
    final path = Path()
      ..moveTo(0, arm)
      ..lineTo(0, 0)
      ..lineTo(arm, 0)
      ..moveTo(size.width - arm, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, arm)
      ..moveTo(0, size.height - arm)
      ..lineTo(0, size.height)
      ..lineTo(arm, size.height)
      ..moveTo(size.width - arm, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, size.height - arm);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SignatureMarkPainter extends CustomPainter {
  final double progress;
  const _SignatureMarkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .05, size.height * .75)
      ..cubicTo(size.width * .17, size.height * .6, size.width * .2,
          size.height * .05, size.width * .25, size.height * .2)
      ..cubicTo(size.width * .3, size.height * .45, size.width * .19,
          size.height * .92, size.width * .35, size.height * .55)
      ..cubicTo(size.width * .5, size.height * .1, size.width * .37,
          size.height * .95, size.width * .6, size.height * .52)
      ..cubicTo(size.width * .74, size.height * .28, size.width * .78,
          size.height * .74, size.width * .95, size.height * .4);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress.clamp(0, 1)),
      Paint()
        ..color = const Color(0xFF173B4B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SignatureMarkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
