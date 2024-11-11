import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:handabatamae/models/user_model.dart';
import 'package:handabatamae/pages/main/main_page.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'login_page.dart';
import 'package:handabatamae/services/auth_service.dart';
import '../widgets/buttons/custom_button.dart';
import '../widgets/text_with_shadow.dart';
import '/localization/splash/localization.dart'; // Import the localization file
import '../widgets/loading_widget.dart';
import 'package:handabatamae/services/stage_service.dart';
import 'package:handabatamae/services/badge_service.dart';
import 'package:handabatamae/services/banner_service.dart';
import 'package:handabatamae/services/avatar_service.dart';

class SplashPage extends StatefulWidget {
  final String selectedLanguage;
  const SplashPage({super.key, required this.selectedLanguage});

  @override
  SplashPageState createState() => SplashPageState();
}

class SplashPageState extends State<SplashPage> {
  String _selectedLanguage = 'en';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.selectedLanguage;
    // Call prefetch after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchData();
    });
  }

  Future<void> _prefetchData() async {
    try {
      print('🚀 Starting data prefetch...');
      setState(() => _isLoading = true);

      final stageService = StageService();
      final badgeService = BadgeService();
      final bannerService = BannerService();
      final avatarService = AvatarService();
      final authService = AuthService();

      // Check connection quality first
      print('📡 Checking connection quality...');
      await avatarService.connectionQuality.first;  // Wait for first connection check

      // Priority load current user's avatar
      print('👤 Checking user profile...');
      final userProfile = await authService.getUserProfile();
      if (userProfile != null) {
        print('🎯 Prefetching current user avatar...');
        await avatarService.getAvatarDetails(
          userProfile.avatarId,
          priority: LoadPriority.CRITICAL
        );
      }

      print('📥 Fetching all resources...');
      
      // Keep existing stage prefetches
      final enCategories = await stageService.fetchCategories('en');
      print('✅ EN Categories fetched: ${enCategories.length} categories');
      
      final filCategories = await stageService.fetchCategories('fil');
      print('✅ FIL Categories fetched: ${filCategories.length} categories');

      // Keep stage fetches for categories
      print('📥 Fetching stages for all categories...');
      for (var category in enCategories) {
        print('📥 Fetching EN stages for category: ${category['id']}');
        final stages = await stageService.fetchStages('en', category['id']);
        print('✅ EN Stages fetched for ${category['name']}: ${stages.length} stages');
      }

      for (var category in filCategories) {
        print('📥 Fetching FIL stages for category: ${category['id']}');
        final stages = await stageService.fetchStages('fil', category['id']);
        print('✅ FIL Stages fetched for ${category['name']}: ${stages.length} stages');
      }

      // Load visible avatars first with HIGH priority
      print('📥 Fetching initial avatars...');
      final avatars = await avatarService.fetchAvatars();
      print('✅ Avatars fetched and cached: ${avatars.length} avatars');

      // Then trigger background sync for remaining avatars
      print('📥 Background loading remaining avatars...');
      avatarService.triggerBackgroundSync();

      // Verify cache integrity
      print('🔍 Verifying avatar cache integrity...');
      await avatarService.performMaintenance();

      // Keep existing badge and banner prefetches
      print('📥 Fetching badges...');
      // Use existing badgeService instance
      
      // First fetch user profile to get current quest and showcase
      // Use existing userProfile instance
      if (userProfile != null) {
        // 1. Load current quest badges with CRITICAL priority
        print('🎯 Prefetching current quest badges...');
        await badgeService.fetchBadgesWithPriority(
          'Quake Quest', // Default to first quest since currentQuest isn't available
          userProfile.badgeShowcase,
          priority: BadgePriority.CURRENT_QUEST
        );

        // 2. Load showcase badges with HIGH priority
        print('🎯 Prefetching showcase badges...');
        await badgeService.fetchBadgesWithPriority(
          'Quake Quest',
          userProfile.badgeShowcase,
          priority: BadgePriority.SHOWCASE
        );

        // 3. Trigger background loading for other badges
        print('📥 Background loading remaining badges...');
        badgeService.triggerBackgroundSync();
      }

      print('✅ Badge prefetch complete');

      final results = await Future.wait([
        badgeService.fetchBadges().then((badges) {
          print('✅ Badges fetched: ${badges.length} badges');
          return badges;
        }),
        bannerService.fetchBanners().then((banners) {
          print('✅ Banners fetched: ${banners.length} banners');
          return banners;
        }),
      ]);

      print('🎉 All resources prefetched and cached successfully!');
      print('📊 Summary:');
      print('   - EN Categories: ${enCategories.length}');
      print('   - FIL Categories: ${filCategories.length}');
      print('   - Avatars: ${avatars.length}');
      print('   - Current user avatar cached: ${userProfile != null}');
      print('   - Badges: ${results[0].length}');
      print('   - Banners: ${results[1].length}');

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e, stackTrace) {
      print('❌ Error during prefetch: $e');
      print('❌ Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  static const double titleFontSize = 90;
  static const double subtitleFontSize = 85;
  static const double buttonWidthFactor = 0.8;
  static const double buttonHeight = 55;
  static const double verticalOffset = -40.0;
  static const double topPadding = 210.0;
  static const double bottomPadding = 140.0;
  static const double buttonSpacing = 20.0;

  Future<void> _signInAnonymously(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const LoadingWidget();
        },
      );

      AuthService authService = AuthService();

      // Check if a guest account already exists
      String? guestUid = await authService.getGuestAccountDetails();
      if (guestUid != null) {
        // Sign in with the existing guest account
        UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();
        if (userCredential.user != null) {
          // Check if the widget is still mounted before using the context
          if (!context.mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MainPage(selectedLanguage: _selectedLanguage)),
          );
          return;
        }
      }

      // If no guest account exists, create a new one
      UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();
      User? user = userCredential.user;
      if (user != null) {
        await authService.createGuestProfile(user);
      }

      // Check if the widget is still mounted before using the context
      if (!context.mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainPage(selectedLanguage: _selectedLanguage)),
      );
    } catch (e) {
      // Remove the loading dialog in case of error
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (!context.mounted) return;

      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sign in anonymously: $e')),
      );
    }
  }

  Future<void> _checkSignInStatus(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const LoadingWidget();
      },
    );

    AuthService authService = AuthService();
    bool isSignedIn = await authService.isSignedIn();

    if (!context.mounted) return;

    // Remove the loading dialog
    Navigator.of(context).pop();

    if (isSignedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainPage(selectedLanguage: _selectedLanguage)),
      );
    } else {
      // Check for local guest profile
      UserProfile? localGuestProfile = await authService.getLocalGuestProfile();

      if (!context.mounted) return;

      if (localGuestProfile != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainPage(selectedLanguage: _selectedLanguage)),
        );
      } else {
        // Sign in anonymously if no local guest profile exists
        _signInAnonymously(context);
      }
    }
  }

  void _changeLanguage(String language) {
    setState(() {
      _selectedLanguage = language;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ResponsiveBreakpoints(
            breakpoints: const [
              Breakpoint(start: 0, end: 450, name: MOBILE),
              Breakpoint(start: 451, end: 800, name: TABLET),
              Breakpoint(start: 801, end: 1920, name: DESKTOP),
              Breakpoint(start: 1921, end: double.infinity, name: '4K'),
            ],
            child: MaxWidthBox(
              maxWidth: 1200,
              child: ResponsiveScaledBox(
                width: ResponsiveValue<double>(
                  context,
                  defaultValue: 450.0,
                  conditionalValues: [
                    const Condition.equals(name: MOBILE, value: 450.0),
                    const Condition.between(start: 800, end: 1100, value: 800.0),
                    const Condition.between(start: 1000, end: 1200, value: 1000.0),
                  ],
                ).value,
                child: Stack(
                  children: [
                    SvgPicture.asset(
                      'assets/backgrounds/background.svg',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                    Positioned(
                      top: 60,
                      right: 35,
                      child: DropdownButton<String>(
                        icon: const Icon(Icons.language, color: Colors.white, size: 40), // Larger icon
                        underline: Container(), // Remove underline
                        items: const [
                          DropdownMenuItem(
                            value: 'en',
                            child: Text('English'),
                          ),
                          DropdownMenuItem(
                            value: 'fil',
                            child: Text('Filipino'),
                          ),
                        ],
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            _changeLanguage(newValue);
                          }
                        },
                      ),
                    ),
                    Center(
                      child: Column(
                        children: <Widget>[
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: (ResponsiveValue<double>(
                                  context,
                                  defaultValue: topPadding,
                                  conditionalValues: [
                                    const Condition.smallerThan(name: MOBILE, value: topPadding * 0.8),
                                    const Condition.largerThan(name: MOBILE, value: topPadding * 1.2),
                                  ],
                                ).value), // Provide a default value
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: TextWithShadow(
                                      text: SplashLocalization.translate('title', _selectedLanguage),
                                      fontSize: (ResponsiveValue<double>(
                                        context,
                                        defaultValue: titleFontSize,
                                        conditionalValues: [
                                          const Condition.smallerThan(name: MOBILE, value: titleFontSize * 0.8),
                                          const Condition.largerThan(name: MOBILE, value: titleFontSize * 1.2),
                                        ],
                                      ).value), // Provide a default value
                                    ),
                                  ),
                                  Transform.translate(
                                    offset: Offset(0, (ResponsiveValue<double>(
                                      context,
                                      defaultValue: verticalOffset,
                                      conditionalValues: [
                                        const Condition.smallerThan(name: MOBILE, value: verticalOffset * 0.8),
                                        const Condition.largerThan(name: MOBILE, value: verticalOffset * 1.2),
                                      ],
                                    ).value)), // Provide a default value
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: TextWithShadow(
                                        text: SplashLocalization.translate('subtitle', _selectedLanguage),
                                        fontSize: (ResponsiveValue<double>(
                                          context,
                                          defaultValue: subtitleFontSize,
                                          conditionalValues: [
                                            const Condition.smallerThan(name: MOBILE, value: subtitleFontSize * 0.8),
                                            const Condition.largerThan(name: MOBILE, value: subtitleFontSize * 1.2),
                                          ],
                                        ).value), // Provide a default value
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 0),
                          SizedBox(
                            width: (ResponsiveValue<double>(
                              context,
                              defaultValue: MediaQuery.of(context).size.width * buttonWidthFactor,
                              conditionalValues: [
                                Condition.smallerThan(name: MOBILE, value: MediaQuery.of(context).size.width * 0.9),
                                Condition.largerThan(name: MOBILE, value: MediaQuery.of(context).size.width * buttonWidthFactor),
                              ],
                            ).value), // Provide a default value
                            height: (ResponsiveValue<double>(
                              context,
                              defaultValue: buttonHeight,
                              conditionalValues: [
                                const Condition.smallerThan(name: MOBILE, value: buttonHeight * 0.8),
                                const Condition.largerThan(name: MOBILE, value: buttonHeight * 1.2),
                              ],
                            ).value), // Provide a default value
                            child: CustomButton(
                              text: SplashLocalization.translate('login', _selectedLanguage),
                              color: const Color(0xFF351B61),
                              textColor: Colors.white,
                              width: (ResponsiveValue<double>(
                                context,
                                defaultValue: MediaQuery.of(context).size.width * buttonWidthFactor,
                                conditionalValues: [
                                  Condition.smallerThan(name: MOBILE, value: MediaQuery.of(context).size.width * 0.9),
                                  Condition.largerThan(name: MOBILE, value: MediaQuery.of(context).size.width * buttonWidthFactor),
                                ],
                              ).value), // Provide a default value
                              height: (ResponsiveValue<double>(
                                context,
                                defaultValue: buttonHeight,
                                conditionalValues: [
                                  const Condition.smallerThan(name: MOBILE, value: buttonHeight * 0.8),
                                  const Condition.largerThan(name: MOBILE, value: buttonHeight * 1.2),
                                ],
                              ).value), // Provide a default value
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => LoginPage(selectedLanguage: _selectedLanguage)),
                                );
                              },
                            ),
                          ),
                          SizedBox(
                            height: (ResponsiveValue<double>(
                              context,
                              defaultValue: buttonSpacing,
                              conditionalValues: [
                                const Condition.smallerThan(name: MOBILE, value: buttonSpacing * 0.8),
                                const Condition.largerThan(name: MOBILE, value: buttonSpacing * 1.2),
                              ],
                            ).value), // Provide a default value
                          ),
                          SizedBox(
                            width: (ResponsiveValue<double>(
                              context,
                              defaultValue: MediaQuery.of(context).size.width * buttonWidthFactor,
                              conditionalValues: [
                                Condition.smallerThan(name: MOBILE, value: MediaQuery.of(context).size.width * 0.9),
                                Condition.largerThan(name: MOBILE, value: MediaQuery.of(context).size.width * buttonWidthFactor),
                              ],
                            ).value), // Provide a default value
                            height: (ResponsiveValue<double>(
                              context,
                              defaultValue: buttonHeight,
                              conditionalValues: [
                                const Condition.smallerThan(name: MOBILE, value: buttonHeight * 0.8),
                                const Condition.largerThan(name: MOBILE, value: buttonHeight * 1.2),
                              ],
                            ).value), // Provide a default value
                            child: CustomButton(
                              text: SplashLocalization.translate('play_now', _selectedLanguage),
                              color: const Color(0xFFF1B33A),
                              textColor: Colors.black,
                              width: (ResponsiveValue<double>(
                                context,
                                defaultValue: MediaQuery.of(context).size.width * buttonWidthFactor,
                                conditionalValues: [
                                  Condition.smallerThan(name: MOBILE, value: MediaQuery.of(context).size.width * 0.9),
                                  Condition.largerThan(name: MOBILE, value: MediaQuery.of(context).size.width * buttonWidthFactor),
                                ],
                              ).value), // Provide a default value
                              height: (ResponsiveValue<double>(
                                context,
                                defaultValue: buttonHeight,
                                conditionalValues: [
                                  const Condition.smallerThan(name: MOBILE, value: buttonHeight * 0.8),
                                  const Condition.largerThan(name: MOBILE, value: buttonHeight * 1.2),
                                ],
                              ).value), // Provide a default value
                              onTap: () {
                                _checkSignInStatus(context);
                              },
                            ),
                          ),
                          SizedBox(
                            height: (ResponsiveValue<double>(
                              context,
                              defaultValue: bottomPadding,
                              conditionalValues: [
                                const Condition.smallerThan(name: MOBILE, value: bottomPadding * 0.8),
                                const Condition.largerThan(name: MOBILE, value: bottomPadding * 1.2),
                              ],
                            ).value), // Provide a default value
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Text(
                              SplashLocalization.translate('copyright', _selectedLanguage),
                              style: GoogleFonts.vt323(fontSize: 16, color: Colors.grey),
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
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: LoadingWidget(),
              ),
            ),
        ],
      ),
    );
  }
}