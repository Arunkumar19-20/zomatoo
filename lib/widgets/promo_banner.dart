import 'package:flutter/material.dart';

/// Zomato-style horizontal promo banner carousel
class PromoBanner extends StatefulWidget {
  const PromoBanner({super.key});

  @override
  State<PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends State<PromoBanner> {
  final PageController _controller = PageController(viewportFraction: 0.90);
  int _current = 0;

  final List<_PromoData> _promos = const [
    _PromoData(
      gradient: [Color(0xFFE23744), Color(0xFFAB1A26)],
      title: '50% OFF up to ₹100',
      subtitle: 'Use code WELCOME50 on your first order',
      tag: 'New User Deal',
      emoji: '🎉',
    ),
    _PromoData(
      gradient: [Color(0xFFFF6B35), Color(0xFFE84393)],
      title: 'Free Delivery',
      subtitle: 'On orders above ₹199 — limited time!',
      tag: 'Today Only',
      emoji: '🚀',
    ),
    _PromoData(
      gradient: [Color(0xFF1BA672), Color(0xFF148F77)],
      title: 'Biryani Festival',
      subtitle: 'Flat 30% off on all biryani orders',
      tag: 'Trending',
      emoji: '🥘',
    ),
    _PromoData(
      gradient: [Color(0xFF5B5EA6), Color(0xFF9B2335)],
      title: 'Late Night Cravings?',
      subtitle: 'Restaurants open 24/7 near you',
      tag: 'Night Delivery',
      emoji: '🌙',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 110,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: _promos.length,
            itemBuilder: (ctx, i) {
              final p = _promos[i];
              return AnimatedScale(
                scale: _current == i ? 1.0 : 0.96,
                duration: const Duration(milliseconds: 250),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: p.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.22),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                p.tag,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              p.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              p.subtitle,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(p.emoji, style: const TextStyle(fontSize: 42)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Dot indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _promos.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 5,
              width: _current == i ? 20 : 5,
              decoration: BoxDecoration(
                color: _current == i
                    ? const Color(0xFFE23744)
                    : const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PromoData {
  final List<Color> gradient;
  final String title;
  final String subtitle;
  final String tag;
  final String emoji;

  const _PromoData({
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.emoji,
  });
}
