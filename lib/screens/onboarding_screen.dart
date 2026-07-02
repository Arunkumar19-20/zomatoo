import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/scale_tap.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<Map<String, String>> _slides = [
    {
      "title": "Discover the Best Local Food",
      "subtitle": "Browse through thousands of top-rated local restaurants and satisfy your cravings in seconds.",
      "image": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&auto=format&fit=crop&q=80",
    },
    {
      "title": "Order Your Favorites Instantly",
      "subtitle": "Order with easy payment options and track your food as it's prepared and delivered straight to your door.",
      "image": "https://images.unsplash.com/photo-1498837167922-ddd27525d352?w=600&auto=format&fit=crop&q=80",
    },
    {
      "title": "Super Fast Doorstep Delivery",
      "subtitle": "Experience hot, fresh food delivered in record time by our dedicated rider partners.",
      "image": "https://images.unsplash.com/photo-1617347454431-f49d7ff5c3b1?w=600&auto=format&fit=crop&q=80",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Orange gradient background with abstract shapes mimicking the attached pictures
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.orangeGradient,
            ),
          ),
          
          // Abstract wave decorations
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Slide Content
          SafeArea(
            child: Column(
              children: [
                // Top Skip button
                Align(
                  alignment: Alignment.topRight,
                  key: const ValueKey('skip_button_align'),
                  child: _currentIndex < 2
                      ? ScaleTap(
                          onTap: () {
                            _pageController.animateToPage(
                              2,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                            child: Text(
                              "Skip",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox(height: 48),
                ),
                
                // Page view for slides
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Premium food image with rounded borders and a nice white card framing it
                              Container(
                                padding: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    slide["image"]!,
                                    height: 240,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        height: 240,
                                        color: Colors.white.withValues(alpha: 0.1),
                                        child: const Center(
                                          child: CircularProgressIndicator(color: Colors.white),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                slide["title"]!,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                slide["subtitle"]!,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom section: dots and primary CTA
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Dots Indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _slides.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: _currentIndex == index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _currentIndex == index ? Colors.white : Colors.white.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Button CTA
                      PrimaryButton(
                        text: _currentIndex == 2 ? "Get Started" : "Next",
                        onPressed: () {
                          if (_currentIndex < 2) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            Navigator.of(context).pushReplacementNamed('/login');
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
