import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class OffersScreen extends StatelessWidget {
  const OffersScreen({super.key});

  static const _bannerOffers = [
    _Offer(
      gradient: AppTheme.bannerGradient1,
      emoji: '🎉',
      title: '50% OFF',
      subtitle: 'On your first 3 orders',
      code: 'WELCOME50',
      validity: 'Valid till 30 Sep 2026',
      tag: 'FOR YOU',
    ),
    _Offer(
      gradient: AppTheme.bannerGradient2,
      emoji: '🚀',
      title: 'Free Delivery',
      subtitle: 'On orders above ₹299',
      code: 'FREEDEL',
      validity: 'Valid till 31 Dec 2026',
      tag: 'ALL USERS',
    ),
  ];

  static const _otherOffers = [
    _Offer(
      gradient: AppTheme.bannerGradient3,
      emoji: '🥘',
      title: '30% OFF',
      subtitle: 'On Royal Biryani House orders',
      code: 'BIRYANI30',
      validity: 'Valid this weekend',
      tag: 'RESTAURANT',
    ),
    _Offer(
      gradient: LinearGradient(
        colors: [Color(0xFF1A0A00), Color(0xFF5D2500)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '🍕',
      title: '20% OFF',
      subtitle: 'On all Pizza orders',
      code: 'FOOD20',
      validity: 'Valid till 25 Sep 2026',
      tag: 'FOOD TYPE',
    ),
    _Offer(
      gradient: LinearGradient(
        colors: [Color(0xFF001A33), Color(0xFF003D66)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '💳',
      title: '10% OFF',
      subtitle: 'On UPI payments',
      code: 'SAVE10',
      validity: 'Valid every day',
      tag: 'PAYMENT',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text(
              'Offers & Coupons',
              style: TextStyle(
                color: AppTheme.textDark,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: Colors.grey.shade200),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Enter coupon code
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: AppTheme.shadowSm,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.confirmation_number_rounded,
                              color: AppTheme.primaryColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Have a coupon code?',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppTheme.textLightest),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const _SectionHeader('⭐ Top Deals'),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Top deal cards
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: _OfferCard(offer: _bannerOffers[i]),
              ),
              childCount: _bannerOffers.length,
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: const _SectionHeader('🎁 More Offers'),
            ),
          ),

          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: _OfferCard(offer: _otherOffers[i]),
              ),
              childCount: _otherOffers.length,
            ),
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: AppTheme.textDark,
      ),
    );
  }
}

class _Offer {
  final LinearGradient gradient;
  final String emoji;
  final String title;
  final String subtitle;
  final String code;
  final String validity;
  final String tag;

  const _Offer({
    required this.gradient,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.code,
    required this.validity,
    required this.tag,
  });
}

class _OfferCard extends StatelessWidget {
  final _Offer offer;
  const _OfferCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: offer.gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadowMd,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(offer.emoji, style: const TextStyle(fontSize: 42)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      offer.tag,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    offer.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    offer.subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: offer.code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('Copied "${offer.code}" to clipboard!'),
                              backgroundColor: AppTheme.successColor,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                style: BorderStyle.solid),
                          ),
                          child: Row(
                            children: [
                              Text(
                                offer.code,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.copy_rounded,
                                  color: Colors.white70, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    offer.validity,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
