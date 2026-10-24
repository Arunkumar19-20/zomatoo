import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../theme/app_theme.dart';

class OfferBannerCarousel extends StatefulWidget {
  const OfferBannerCarousel({super.key});

  @override
  State<OfferBannerCarousel> createState() => _OfferBannerCarouselState();
}

class _OfferBannerCarouselState extends State<OfferBannerCarousel> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _currentPage = 0;

  static const _banners = [
    _BannerData(
      gradient: AppTheme.bannerGradient1,
      emoji: '🍕',
      tag: 'LIMITED TIME',
      title: '50% OFF',
      subtitle: 'On your first 3 orders',
      code: 'WELCOME50',
      codeColor: Color(0xFFFFA000),
    ),
    _BannerData(
      gradient: AppTheme.bannerGradient2,
      emoji: '🍔',
      tag: 'WEEKDAY DEAL',
      title: 'Free Delivery',
      subtitle: 'On orders above ₹299',
      code: 'FREEDEL',
      codeColor: Color(0xFFCE93D8),
    ),
    _BannerData(
      gradient: AppTheme.bannerGradient3,
      emoji: '🥘',
      tag: 'BIRYANI SPECIAL',
      title: '30% OFF',
      subtitle: 'On Royal Biryani House',
      code: 'BIRYANI30',
      codeColor: Color(0xFF81C784),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % _banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _controller,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (ctx, i) => _BannerTile(data: _banners[i]),
          ),
        ),
        const SizedBox(height: 10),
        SmoothPageIndicator(
          controller: _controller,
          count: _banners.length,
          effect: ExpandingDotsEffect(
            dotWidth: 6,
            dotHeight: 6,
            expansionFactor: 3,
            spacing: 5,
            activeDotColor: AppTheme.primaryColor,
            dotColor: Colors.grey.shade300,
          ),
        ),
      ],
    );
  }
}

class _BannerData {
  final LinearGradient gradient;
  final String emoji;
  final String tag;
  final String title;
  final String subtitle;
  final String code;
  final Color codeColor;

  const _BannerData({
    required this.gradient,
    required this.emoji,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.code,
    required this.codeColor,
  });
}

class _BannerTile extends StatelessWidget {
  final _BannerData data;
  const _BannerTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: data.gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.shadowMd,
      ),
      child: Stack(
        children: [
          // Background decorative circle
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          data.tag,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: data.codeColor.withOpacity(0.6)),
                          borderRadius: BorderRadius.circular(6),
                          color: data.codeColor.withOpacity(0.1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_offer_rounded,
                                size: 11, color: data.codeColor),
                            const SizedBox(width: 4),
                            Text(
                              'USE ${data.code}',
                              style: TextStyle(
                                color: data.codeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  data.emoji,
                  style: const TextStyle(fontSize: 72),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
