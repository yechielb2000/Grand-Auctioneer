import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/assets/app_assets.dart';
import 'app/config/app_config.dart';
import 'app/providers/app_services.dart';
import 'app/theme/app_colors.dart';
import 'app/widgets/app_icon.dart';
import 'app/widgets/game_artwork.dart';
import 'core/models/user_account.dart';
import 'features/auth/domain/auth_service.dart';
import 'features/home/presentation/connected_game_home.dart';
import 'features/map_properties/presentation/interactive_world_map.dart';
import 'game_state.dart';
import 'l10n/app_localization_helpers.dart';
import 'l10n/generated/app_localizations.dart';
import 'services/ads/rewarded_ad_service.dart';

const _background = AppColors.background;
const _surface = AppColors.surface;
const _gold = AppColors.primaryGold;
const _green = AppColors.accentGreen;
const _cyan = AppColors.diamondCyan;
const _muted = AppColors.textSecondary;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AuctionEmpireApp());
}
class AuctionEmpireApp extends StatefulWidget {
  const AuctionEmpireApp({super.key});

  @override
  State<AuctionEmpireApp> createState() => _AuctionEmpireAppState();
}

class _AuctionEmpireAppState extends State<AuctionEmpireApp> {
  Locale? _locale;
  late Future<AppServices> _services = _initializeServices();

  void _retryInitialization() {
    setState(() => _services = _initializeServices());
  }

  Future<AppServices> _initializeServices() async {
    await Firebase.initializeApp();
    return AppServices.initialize();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
        locale: _locale,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => Directionality(
          textDirection: AppLocalizations.of(context)!.localeName == 'he' ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        ),
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primaryGold,
            secondary: AppColors.accentGreen,
            surface: AppColors.surface,
            error: AppColors.accentRed,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.textPrimary,
            surfaceTintColor: Colors.transparent,
          ),
          cardTheme: CardThemeData(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
        home: AppConfig.firebaseEnabled
            ? FutureBuilder<AppServices>(
                future: _services,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _StartupMessage(
                      title: AppLocalizations.of(context)!.firebaseStartErrorTitle,
                      message: AppLocalizations.of(context)!.firebaseStartErrorMessage('${snapshot.error}'),
                      icon: Icons.cloud_off_outlined,
                      actionLabel: AppLocalizations.of(context)!.retrySetup,
                      onAction: _retryInitialization,
                    );
                  }
                  if (!snapshot.hasData) {
                    return _StartupMessage(
                      title: AppLocalizations.of(context)!.firebaseConnecting,
                      message: AppLocalizations.of(context)!.firebasePreparing,
                      loading: true,
                    );
                  }
                  final services = snapshot.data!;
                  return _AuthGate(
                    services: services,
                    onLocaleChanged: (locale) => setState(() => _locale = locale),
                  );
                },
              )
            : const _SetupRequiredScreen(),
      );
}

class _AuthGate extends StatefulWidget {
  const _AuthGate({required this.services, required this.onLocaleChanged});
  final AppServices services;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  StreamSubscription? _subscription;
  UserAccount? _account;
  Object? _authError;
  bool _loading = true;
  bool _signingIn = false;

  @override
  void initState() {
    super.initState();
    _watchAuth();
  }

  void _watchAuth() {
    _subscription?.cancel();
    setState(() { _loading = true; _authError = null; });
    _subscription = widget.services.auth.watchCurrentUser().listen(
      (account) {
        if (!mounted) return;
        setState(() { _account = account; _loading = false; _authError = null; });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() { _authError = error; _loading = false; });
      },
    );
  }

  Future<void> _signIn() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() { _signingIn = true; _authError = null; });
    try {
      await widget.services.auth.signInWithGoogle();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _authError = l10n.googleSignInError('${error.message ?? error.code}'));
    } catch (error) {
      if (!mounted) return;
      final text = error.toString();
      if (!text.toLowerCase().contains('cancel')) setState(() => _authError = text);
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await widget.services.auth.signOut();
    } catch (error) {
      if (mounted) setState(() => _authError = AppLocalizations.of(context)!.signOutError('$error'));
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    unawaited(widget.services.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) return _StartupMessage(title: l10n.checkingAccount, message: l10n.connectingSecurely, loading: true);
    if (_authError != null) return _StartupMessage(
      title: l10n.authNeedsAttention,
      message: '$_authError',
      icon: Icons.lock_outline,
      actionLabel: l10n.retry,
      onAction: _watchAuth,
    );
    if (_account == null) return _SignInScreen(busy: _signingIn, onSignIn: _signIn, error: _authError);
    return Scaffold(
      body: SafeArea(child: Column(children: [
        Expanded(child: ConnectedGameHome(services: widget.services, onLocaleChanged: widget.onLocaleChanged)),
        Align(alignment: Alignment.centerRight, child: TextButton.icon(
          onPressed: _signOut,
          icon: const Icon(Icons.logout_rounded, size: 17),
          label: Text(l10n.signOut),
        )),
      ])),
    );
  }
}

class _SetupRequiredScreen extends StatelessWidget {
  const _SetupRequiredScreen();
  @override
  Widget build(BuildContext context) => _StartupMessage(
    title: AppLocalizations.of(context)!.firebaseSetupRequired,
    message: AppLocalizations.of(context)!.firebaseSetupMessage(AppConfig.firebaseNativeSetupMessage, AppConfig.firebaseSetupCommand),
    icon: Icons.settings_suggest_outlined,
  );
}

class _SignInScreen extends StatelessWidget {
  const _SignInScreen({required this.busy, required this.onSignIn, this.error});
  final bool busy;
  final VoidCallback onSignIn;
  final Object? error;
  @override
  Widget build(BuildContext context) => _StartupMessage(
    title: AppLocalizations.of(context)!.welcomeTitle,
    message: AppLocalizations.of(context)!.signInWorkspace,
    icon: Icons.diamond_outlined,
    actionLabel: busy ? AppLocalizations.of(context)!.signingIn : AppLocalizations.of(context)!.continueWithGoogle,
    onAction: busy ? null : onSignIn,
    loading: busy,
    detail: error?.toString(),
  );
}

class _StartupMessage extends StatelessWidget {
  const _StartupMessage({required this.title, required this.message, this.icon, this.loading = false, this.actionLabel, this.onAction, this.detail});
  final String title, message;
  final IconData? icon;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? detail;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.outline)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 54, height: 54, decoration: BoxDecoration(color: AppColors.primaryGold.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)), child: Center(child: loading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGold)) : Icon(icon ?? Icons.info_outline, color: AppColors.primaryGold, size: 27))),
          const SizedBox(height: 24),
          Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 25, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppColors.textSecondary, height: 1.55)),
          if (detail != null) ...[const SizedBox(height: 12), SelectableText(detail!, style: const TextStyle(color: AppColors.accentRed, fontSize: 13))],
          if (actionLabel != null) ...[const SizedBox(height: 24), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onAction, icon: const Icon(Icons.arrow_forward_rounded), label: Text(actionLabel!)))],
        ]),
      ),
    )))),
  );
}
class GameHome extends StatefulWidget {
  const GameHome({
    required this.game,
    required this.services,
    required this.rewardedAds,
    required this.onLocaleChanged,
    super.key,
  });

  final GameState game;
  final AppServices? services;
  final RewardedAdService? rewardedAds;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<GameHome> createState() => _GameHomeState();
}

class _GameHomeState extends State<GameHome> {
  int selectedTab = 0;
  StreamSubscription<RemoteMessage>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _messageSubscription =
        widget.services?.notifications.foregroundMessages.listen(
      _showOutbidMessage,
      onError: (Object error, StackTrace stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'Firebase Messaging',
            context: ErrorDescription(
              'while listening for foreground auction notifications',
            ),
          ),
        );
      },
    );
  }

  void _showOutbidMessage(RemoteMessage message) {
    if (message.data['type'] != 'outbid') return;
    final l10n = AppLocalizations.of(context)!;
    final title = message.notification?.title ?? l10n.outbidTitle;
    final body = message.notification?.body ??
        message.data['body']?.toString() ??
        l10n.outbidBody;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('$title: $body'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    });
  }

  @override
  void dispose() {
    unawaited(_messageSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final game = widget.game;
    final pages = [
      l10n.navMap,
      l10n.pageAuctionHouse,
      l10n.pageMyAssets,
      l10n.pageBankRewards,
      l10n.navProfile,
      l10n.preferences,
    ];
    const screenNames = [
      'World',
      'Auction House',
      'My Assets',
      'Bank & Rewards',
      'Profile',
      'Settings',
    ];
    final screens = [
      MapScreen(game: game),
      AuctionScreen(game: game, isActive: selectedTab == 1),
      InventoryScreen(game: game),
      RewardsScreen(game: game, rewardedAds: widget.rewardedAds),
      ProfileScreen(
        game: game,
        authService: widget.services?.auth,
      ),
      SettingsScreen(onLocaleChanged: widget.onLocaleChanged),
    ];
    void selectDestination(int index) {
      setState(() => selectedTab = index);
      final analytics = widget.services?.analytics;
      if (analytics != null) {
        unawaited(_logScreenView(analytics, screenNames[index]));
      }
    }

    final destinations = [
      NavigationDestination(
        icon: AppIcon(assetName: AppAssets.map, color: AppColors.textSecondary, semanticLabel: l10n.navMap),
        selectedIcon: AppIcon(assetName: AppAssets.map, color: _gold, semanticLabel: l10n.navMap),
        label: l10n.navMap,
      ),
      NavigationDestination(
        icon: AppIcon(assetName: AppAssets.market, color: AppColors.textSecondary, semanticLabel: l10n.navAuctions),
        selectedIcon: AppIcon(assetName: AppAssets.market, color: _gold, semanticLabel: l10n.navAuctions),
        label: l10n.navAuctions,
      ),
      NavigationDestination(
        icon: AppIcon(assetName: AppAssets.warehouse, color: AppColors.textSecondary, semanticLabel: l10n.navAssets),
        selectedIcon: AppIcon(assetName: AppAssets.warehouse, color: _gold, semanticLabel: l10n.navAssets),
        label: l10n.navAssets,
      ),
      NavigationDestination(
        icon: AppIcon(assetName: AppAssets.cash, color: AppColors.textSecondary, semanticLabel: l10n.navBank),
        selectedIcon: AppIcon(assetName: AppAssets.cash, color: _gold, semanticLabel: l10n.navBank),
        label: l10n.navBank,
      ),
      NavigationDestination(
        icon: AppIcon(assetName: AppAssets.profile, color: AppColors.textSecondary, semanticLabel: l10n.navProfile),
        selectedIcon: AppIcon(assetName: AppAssets.profile, color: _gold, semanticLabel: l10n.navProfile),
        label: l10n.navProfile,
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings_rounded, color: _gold),
        label: l10n.preferences,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            AppIcon(
              assetName: AppAssets.gem,
              color: _cyan,
              size: 23,
              semanticLabel: l10n.gems,
            ),
            const SizedBox(width: 8),
            Text(pages[selectedTab], style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -.3)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.preferences,
            onPressed: () => selectDestination(5),
            icon: const Icon(Icons.settings_outlined),
          ),
          if (MediaQuery.sizeOf(context).width >= 460) ...[
            CurrencyPill(assetName: AppAssets.cash, color: _gold, text: money(game.cash)),
            const SizedBox(width: 8),
            CurrencyPill(assetName: AppAssets.gem, color: _cyan, text: '${game.diamonds}'),
            const SizedBox(width: 16),
          ] else ...[
            IconButton(tooltip: l10n.availableCash, onPressed: null, icon: AppIcon(assetName: AppAssets.cash, color: _gold, size: 19)),
            Padding(padding: const EdgeInsets.only(right: 14), child: Text(money(game.cash), style: const TextStyle(color: _gold, fontWeight: FontWeight.w700))),
          ],
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final body = Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: IndexedStack(index: selectedTab, children: screens),
            ),
          );
          if (wide) {
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedTab,
                  onDestinationSelected: selectDestination,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final destination in destinations)
                      NavigationRailDestination(
                        icon: destination.icon,
                        selectedIcon: destination.selectedIcon,
                        label: Text(destination.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            );
          }

          return Column(
            children: [
              Expanded(child: body),
              NavigationBar(
                selectedIndex: selectedTab,
                onDestinationSelected: selectDestination,
                labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
                destinations: destinations,
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _logScreenView(FirebaseAnalytics analytics, String screenName) async {
  try {
    await analytics.logScreenView(
      screenName: screenName,
      screenClass: 'GameHome',
    );
  } on FirebaseException catch (error, stackTrace) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stackTrace,
      library: 'Firebase Analytics',
      context: ErrorDescription('while recording the $screenName screen view'),
    ));
  }
}

class CurrencyPill extends StatelessWidget {
  const CurrencyPill({required this.assetName, required this.color, required this.text, super.key});

  final String assetName;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AppIcon(assetName: assetName, size: 15, color: color),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      );
}

String money(int value) => '\$${value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

Widget sectionTitle(String title, {String? trailing}) => Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 12),
      child: Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -.2))),
        if (trailing != null) Text(trailing, style: const TextStyle(color: _muted, fontSize: 12)),
      ]),
    );

Widget glassCard({required Widget child, EdgeInsets padding = const EdgeInsets.all(18)}) => Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: child,
    );

Widget primaryButton({required String label, required VoidCallback? onPressed, IconData? icon, Color color = _green}) => FilledButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: _background,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

class MapScreen extends StatelessWidget {
  const MapScreen({required this.game, super.key});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width >= 760 ? 32 : 18, 20, MediaQuery.sizeOf(context).width >= 760 ? 32 : 18, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.empireStartsHere,
                style: const TextStyle(color: _muted),
              ),
            ),
            const Icon(Icons.public_rounded, color: _cyan, size: 17),
            const SizedBox(width: 5),
            Text(
              l10n.districtSuburbs,
              style: const TextStyle(
                color: _cyan,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        InteractiveWorldMap(
          game: game,
          onManageHome: () => showPropertySlots(context, game),
        ),
        if (game.properties.isNotEmpty) ...[
          const SizedBox(height: 16),
          glassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.apartment_rounded, color: _gold),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _localizedPropertyName(
                              l10n,
                              game.properties.first.name,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.starterPropertyDetails(
                              game.properties.first.furnitureSlots,
                              game.properties.first.vehicleSlots,
                            ),
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.verified_rounded, color: _green, size: 20),
                  ],
                ),
                const Divider(height: 25, color: Color(0xFF2A3040)),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.passiveRent,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 10,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.rentPerHour,
                            style: const TextStyle(
                              color: _gold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    primaryButton(
                      label: l10n.collectRent,
                      icon: Icons.attach_money_rounded,
                      onPressed: game.collectRent,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.placedSlotsUsed(
                    game.placedFurnitureCount,
                    game.properties.first.furnitureSlots,
                    game.placedVehicleCount,
                    game.properties.first.vehicleSlots,
                  ),
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 7),
                LinearProgressIndicator(
                  value: (game.placedFurnitureCount + game.placedVehicleCount) /
                      (game.properties.first.furnitureSlots +
                          game.properties.first.vehicleSlots),
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(9),
                  color: _gold,
                  backgroundColor: const Color(0xFF2A3040),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: () => showPropertySlots(context, game),
                    icon: const Icon(Icons.grid_view_rounded, size: 17),
                    label: Text(l10n.openPropertySlots),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          l10n.mapInstructions,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 11),
        ),
      ],
    );
  }
}

Future<void> showPropertySlots(BuildContext context, GameState game) async {
  if (game.properties.isEmpty) return;
  final l10n = AppLocalizations.of(context)!;
  final property = game.properties.first;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _surface,
    builder: (context) => SafeArea(
      child: AnimatedBuilder(
        animation: game,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(_localizedPropertyName(l10n, property.name),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(l10n.placeItemHint,
                  style: TextStyle(color: _muted, fontSize: 12)),
              const SizedBox(height: 14),
              _propertySlotSection(
                context,
                game,
                l10n.furniture,
                property.furnitureSlots,
                (item) => item.category != 'Vehicles' &&
                    item.category != 'Boats',
                Icons.chair_rounded,
              ),
              const SizedBox(height: 12),
              _propertySlotSection(
                context,
                game,
                l10n.vehicles,
                property.vehicleSlots,
                (item) =>
                    item.category == 'Vehicles' || item.category == 'Boats',
                Icons.directions_car_rounded,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _propertySlotSection(
  BuildContext context,
  GameState game,
  String category,
  int capacity,
  bool Function(GameItem) accepts,
  IconData icon,
) {
  final l10n = AppLocalizations.of(context)!;
  final placed = game.inventory.where((item) => item.placed && accepts(item));
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(category.toUpperCase(),
          style: const TextStyle(
              color: _cyan, fontSize: 10, letterSpacing: 1.1)),
      const SizedBox(height: 6),
      for (var index = 0; index < capacity; index++)
        Builder(builder: (context) {
          final item = index < placed.length ? placed.elementAt(index) : null;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: Card(
              key: item == null
                  ? ValueKey('empty-$category-$index')
                  : ObjectKey(item),
              color: const Color(0xFF202633),
              child: ListTile(
                leading: item == null
                    ? Icon(icon, color: _muted)
                    : GameItemArtwork(
                        icon: item.icon,
                        itemName: item.name,
                        category: item.category,
                        size: 42,
                        semanticLabel: _localizedItemName(l10n, item.name),
                      ),
                title: Text(
                  item == null
                      ? l10n.emptySlot(category)
                      : _localizedItemName(l10n, item.name),
                ),
                subtitle: Text(item == null
                    ? l10n.assignFromWarehouse
                    : l10n.itemRarityCategory(
                        _localizedRarity(l10n, item.rarity),
                        _localizedCategory(l10n, item.category),
                      )),
                trailing: Icon(
                  item == null
                      ? Icons.add_circle_outline
                      : Icons.tune_rounded,
                  color: item == null ? _green : _muted,
                ),
                onTap: () async {
                  if (item == null) {
                    final available = game.inventory
                        .where((candidate) =>
                            !candidate.placed && accepts(candidate))
                        .toList();
                    if (available.isEmpty) {
                      _showMessage(
                        context,
                        l10n.noMatchingItems,
                      );
                      return;
                    }
                    final selected = await showDialog<GameItem>(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: Text(l10n.chooseCategoryItem(category)),
                        children: available
                            .map((candidate) => SimpleDialogOption(
                                  onPressed: () =>
                                      Navigator.pop(context, candidate),
                                  child: Text(
                                    _localizedItemName(l10n, candidate.name),
                                  ),
                                ))
                            .toList(),
                      ),
                    );
                    if (selected != null && context.mounted) {
                      _showMessage(
                        context,
                        game.placeItem(selected)
                            ? l10n.itemAssigned
                            : l10n.noMatchingSlot,
                      );
                    }
                    return;
                  }

                  if (!context.mounted) return;
                  final remove = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(_localizedItemName(l10n, item.name)),
                      content: Text(
                        l10n.placedItemDescription(
                          _localizedRarity(l10n, item.rarity),
                          _localizedCategory(l10n, item.category).toLowerCase(),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(l10n.keepPlaced),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(l10n.returnToWarehouse),
                        ),
                      ],
                    ),
                  );
                  if (remove == true && context.mounted) {
                    game.removeItemFromProperty(item);
                  }
                },
              ),
            ),
          );
        }),
    ],
  );
}

class AuctionScreen extends StatefulWidget {
  const AuctionScreen({
    required this.game,
    required this.isActive,
    super.key,
  });
  final GameState game;
  final bool isActive;

  @override
  State<AuctionScreen> createState() => _AuctionScreenState();
}

class _AuctionScreenState extends State<AuctionScreen> {
  AuctionMode? filter;
  Timer? refreshTimer;
  final Set<GameAuction> celebratedWinners = {};
  final List<GameAuction> pendingCelebrations = [];
  bool showingCelebration = false;

  @override
  void initState() {
    super.initState();
    refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final changed = widget.game.resolveExpiredAuctions();
        if (changed) {
          for (final auction in widget.game.auctions) {
            if (auction.resolved &&
                auction.playerWon == true &&
                celebratedWinners.add(auction)) {
              pendingCelebrations.add(auction);
            }
          }
          _showNextCelebration();
        }
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant AuctionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) _showNextCelebration();
  }

  void _showNextCelebration() {
    if (!widget.isActive ||
        showingCelebration ||
        pendingCelebrations.isEmpty ||
        !mounted) {
      return;
    }
    showingCelebration = true;
    final auction = pendingCelebrations.removeAt(0);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showAuctionWinCelebration(
        context,
        itemName: auction.itemName,
        price: auction.clearingPrice ?? auction.startingPrice,
      );
      if (!mounted) return;
      showingCelebration = false;
      _showNextCelebration();
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auctions = widget.game.auctions
        .where((auction) =>
            (auction.resolved || !auction.isExpired) &&
            (filter == null || auction.mode == filter))
        .toList();
    return ListView(
      padding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width >= 760 ? 32 : 18, 20, MediaQuery.sizeOf(context).width >= 760 ? 32 : 18, 28),
      children: [
        Row(children: [
          Expanded(child: Text(l10n.liveMarketplace, style: const TextStyle(color: _muted))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: const Color(0xFF3B1821), borderRadius: BorderRadius.circular(20)), child: Row(children: [const Icon(Icons.circle, size: 7, color: Color(0xFFFF5470)), const SizedBox(width: 6), Text(l10n.live, style: const TextStyle(color: Color(0xFFFF7184), fontSize: 10, fontWeight: FontWeight.w800))])),
        ]),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _filterChip(l10n.allModes, filter == null, () => setState(() => filter = null)),
            ...AuctionMode.values.map((mode) => Padding(
                  padding: const EdgeInsetsDirectional.only(start: 7),
                  child: _filterChip(_auctionModeLabel(l10n, mode), filter == mode, () => setState(() => filter = mode)),
                )),
          ]),
        ),
        const SizedBox(height: 16),
        sectionTitle(l10n.endingSoon, trailing: l10n.listingCount(auctions.length)),
        if (auctions.isEmpty)
          glassCard(child: Center(child: Text(l10n.noAuctionsForFilter, style: const TextStyle(color: _muted))))
        else
          ...auctions.map((auction) => Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: AuctionCard(auction: auction, game: widget.game),
              )),
        const SizedBox(height: 7),
        sectionTitle(l10n.listItemOrProperty),
        glassCard(
          child: Row(children: [
            const Icon(Icons.sell_rounded, color: _gold, size: 30),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.turnAssetsIntoCash, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(l10n.chooseAuctionFormat, style: const TextStyle(color: _muted, fontSize: 12)),
            ])),
            IconButton(onPressed: () => showCreateListing(context, widget.game), icon: const Icon(Icons.add_circle_rounded, color: _green, size: 30)),
          ]),
        ),
      ],
    );
  }
}

Widget _filterChip(String label, bool selected, VoidCallback onTap) => FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      side: BorderSide(color: selected ? _gold.withValues(alpha: .4) : Colors.white12),
      backgroundColor: _surface,
      selectedColor: _gold.withValues(alpha: .15),
      labelStyle: TextStyle(color: selected ? _gold : _muted, fontSize: 12, fontWeight: FontWeight.w600),
    );

class AuctionCard extends StatelessWidget {
  const AuctionCard({required this.auction, required this.game, super.key});
  final GameAuction auction;
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final price = auction.currentPrice;
    return glassCard(
      padding: const EdgeInsets.all(15),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GameItemArtwork(
            icon: auction.icon,
            itemName: auction.itemName,
            size: 52,
            semanticLabel: _localizedItemName(l10n, auction.itemName),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _localizedItemName(l10n, auction.itemName),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 5),
            Text(_auctionModeLabel(l10n, auction.mode).toUpperCase(), style: const TextStyle(color: _cyan, fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w800)),
          ])),
          _countdown(context, auction.endsAt),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              auction.mode == AuctionMode.dutch
                  ? l10n.currentPrice
                  : auction.mode == AuctionMode.sealedBid ||
                          auction.mode == AuctionMode.vickrey
                      ? l10n.startingPrice
                      : l10n.currentBid,
              style: const TextStyle(
                  color: _muted, fontSize: 9, letterSpacing: 1),
            ),
            const SizedBox(height: 3),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -.3),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Text(
                money(price),
                key: ValueKey(price),
                style: const TextStyle(
                  color: _gold,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ])),
          if (auction.mode != AuctionMode.dutch &&
              auction.mode != AuctionMode.sealedBid &&
              auction.mode != AuctionMode.vickrey)
            Text(l10n.bidCount(auction.bids), style: const TextStyle(color: _muted, fontSize: 11)),
          const SizedBox(width: 10),
          if (auction.resolved)
            Chip(
                label: Text(l10n.ended),
                visualDensity: VisualDensity.compact,
                labelStyle: const TextStyle(color: _muted, fontSize: 9))
          else if (auction.isPlayerListing)
            Chip(
                label: Text(l10n.yourListing),
                visualDensity: VisualDensity.compact,
                labelStyle: const TextStyle(color: _cyan, fontSize: 9))
          else if (auction.myBid != null &&
              auction.mode != AuctionMode.english)
            Chip(label: Text(l10n.bidPlacedLabel), visualDensity: VisualDensity.compact, labelStyle: const TextStyle(color: _cyan, fontSize: 9))
          else
            primaryButton(
              label: auction.mode == AuctionMode.dutch ? l10n.buyNow : l10n.placeBid,
              icon: auction.mode == AuctionMode.dutch ? Icons.bolt_rounded : Icons.gavel_rounded,
              onPressed: auction.mode == AuctionMode.dutch
                  ? () {
                      final price = auction.currentPrice;
                      final won = game.claimDutchAuction(auction);
                      if (won) {
                        unawaited(showAuctionWinCelebration(
                          context,
                          itemName: auction.itemName,
                          price: price,
                        ));
                      } else {
                        _showMessage(
                          context,
                          l10n.notEnoughCashForClaim,
                        );
                      }
                    }
                  : () => showBidDialog(context, game, auction),
            ),
        ]),
        if (auction.mode == AuctionMode.sealedBid || auction.mode == AuctionMode.vickrey) ...[
          const SizedBox(height: 8),
          if (!auction.resolved)
            Text(
              auction.myBid == null
                  ? l10n.sealedBidsStayHidden
                  : l10n.yourSealedBid(money(auction.myBid!)),
              style: const TextStyle(color: _muted, fontSize: 10),
            )
          else ...[
            Text(
              l10n.revealedBids(
                (auction.revealedBids ?? const <int>[]).map(money).join(' · '),
              ),
              style: const TextStyle(color: _muted, fontSize: 10),
            ),
            const SizedBox(height: 5),
            Text(
              auction.playerWon == true
                  ? l10n.youWonFor(money(auction.clearingPrice ?? auction.startingPrice))
                  : auction.winningBid == null
                      ? l10n.noBidsPlaced
                      : l10n.auctionEndedWinningBid(money(auction.winningBid!)),
              style: TextStyle(
                  color: auction.playerWon == true ? _green : _gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ] else if (auction.resolved) ...[
          const SizedBox(height: 8),
          Text(
            auction.playerWon == true
                ? l10n.youWonFor(money(auction.clearingPrice ?? auction.startingPrice))
                : auction.isPlayerListing
                    ? l10n.listingEndedReturned
                    : l10n.auctionEnded,
            style: const TextStyle(color: _muted, fontSize: 10),
          ),
        ],
      ]),
    );
  }
}

Future<void> showAuctionWinCelebration(
  BuildContext context, {
  required String itemName,
  required int price,
}) async {
  unawaited(HapticFeedback.heavyImpact());
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => _AuctionWinDialog(
      itemName: itemName,
      price: price,
    ),
  );
}

class _AuctionWinDialog extends StatefulWidget {
  const _AuctionWinDialog({required this.itemName, required this.price});

  final String itemName;
  final int price;

  @override
  State<_AuctionWinDialog> createState() => _AuctionWinDialogState();
}

class _AuctionWinDialogState extends State<_AuctionWinDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    duration: const Duration(milliseconds: 1350),
    vsync: this,
  )..forward();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: _gold.withValues(alpha: .35)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 126,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: controller,
                        builder: (context, _) => CustomPaint(
                          painter: _ConfettiPainter(controller.value),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: controller,
                      builder: (context, child) => Transform.rotate(
                        angle: Tween<double>(begin: -.85, end: .04)
                            .chain(CurveTween(curve: Curves.bounceOut))
                            .transform(controller.value),
                        alignment: Alignment.bottomRight,
                        child: child,
                      ),
                      child: const Icon(
                        Icons.gavel_rounded,
                        color: _gold,
                        size: 78,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                l10n.youWon,
                style: TextStyle(
                  color: _gold,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _localizedItemName(l10n, widget.itemName),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                l10n.winningPrice(money(widget.price)),
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: primaryButton(
                  label: l10n.continueLabel,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.progress);

  final double progress;

  static const colors = [
    AppColors.primaryGold,
    AppColors.accentGreen,
    AppColors.diamondCyan,
    Color(0xFFFF7184),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var index = 0; index < 28; index++) {
      final startX =
          (((index * .6180339887) % 1).toDouble()) * size.width;
      final travel = progress * size.height * (1.1 + (index % 5) * .15);
      final x = startX + math.sin(progress * 5 + index) * 9;
      final y = travel - size.height * .25;
      final opacity = (1 - progress * .85).clamp(0.0, 1.0).toDouble();
      final paint = Paint()..color = colors[index % colors.length].withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * 8 + index * .7);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 5, height: 9),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

Widget _countdown(BuildContext context, DateTime end) {
  final l10n = AppLocalizations.of(context)!;
  final remaining = end.difference(DateTime.now());
  if (remaining.isNegative) return Text(l10n.ended, style: const TextStyle(color: _muted, fontSize: 10));
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
  return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
    Text(l10n.endsIn, style: const TextStyle(color: _muted, fontSize: 8, letterSpacing: 1)),
    const SizedBox(height: 3),
    Text(hours > 0 ? l10n.hoursMinutes(hours, minutes) : l10n.minutesSeconds(minutes, seconds), style: const TextStyle(color: Color(0xFFFF7184), fontSize: 12, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
  ]);
}

Future<void> showBidDialog(BuildContext context, GameState game, GameAuction auction) async {
  final l10n = AppLocalizations.of(context)!;
  final minimum = auction.mode == AuctionMode.english &&
          auction.currentBid != null
      ? (auction.currentBid! * 1.05).ceil()
      : auction.startingPrice;
  final amount = await showDialog<int>(
    context: context,
    builder: (_) => BidDialog(
      minimum: minimum,
      balance: game.availableCash,
      sealed: auction.mode == AuctionMode.sealedBid ||
          auction.mode == AuctionMode.vickrey,
    ),
  );
  if (amount == null || !context.mounted) return;
  final placed = game.placeBid(auction, amount);
  if (placed) unawaited(HapticFeedback.mediumImpact());
  _showMessage(context, placed ? l10n.bidPlaced : l10n.bidRejected);
}

class BidDialog extends StatefulWidget {
  const BidDialog({
    required this.minimum,
    required this.balance,
    this.sealed = false,
    super.key,
  });
  final int minimum;
  final int balance;
  final bool sealed;

  @override
  State<BidDialog> createState() => _BidDialogState();
}

class _BidDialogState extends State<BidDialog> {
  late final TextEditingController input = TextEditingController(text: '${widget.minimum}');

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
        title: Text(widget.sealed ? l10n.submitSealedBid : l10n.placeYourBid),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.minimumBalance(money(widget.minimum), money(widget.balance)), style: const TextStyle(color: _muted, fontSize: 12)),
          if (widget.sealed) ...[
            const SizedBox(height: 8),
            Text(
              l10n.sealedBidHint,
              style: const TextStyle(color: _cyan, fontSize: 11),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: input,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(prefixText: '\$ ', labelText: l10n.yourBid, border: const OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, int.tryParse(input.text)),
              child: Text(widget.sealed ? l10n.sealBid : l10n.confirmBid)),
        ],
      );
  }
}

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({required this.game, super.key});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
        padding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width >= 760 ? 32 : 18, 20, MediaQuery.sizeOf(context).width >= 760 ? 32 : 18, 28),
        children: [
          Row(children: [
            Expanded(child: Text(l10n.itemsReadyToTrade(game.inventory.length), style: const TextStyle(color: _muted))),
            const Icon(Icons.warehouse_rounded, color: _gold, size: 18),
            const SizedBox(width: 5),
            Text(l10n.slotCount(game.inventory.length, 20), style: const TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          if (game.inventory.isEmpty)
            glassCard(child: Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(l10n.warehouseEmpty, textAlign: TextAlign.center, style: const TextStyle(color: _muted)))))
          else
            ...game.inventory.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: glassCard(
                    padding: const EdgeInsets.all(13),
                    child: Row(children: [
                      GameItemArtwork(
                        icon: item.icon,
                        itemName: item.name,
                        category: item.category,
                        semanticLabel: _localizedItemName(l10n, item.name),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          _localizedItemName(l10n, item.name),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.itemRarityCategory(
                            _localizedRarity(l10n, item.rarity),
                            _localizedCategory(l10n, item.category),
                          ),
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Text(l10n.estimatedValue(money(item.value)), style: const TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w600)),
                      ])),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: _muted),
                        onSelected: (action) {
                          if (action == 'place') {
                            final placed = game.placeItem(item);
                            _showMessage(context, placed ? l10n.placedInStudio : l10n.slotsInUse);
                          } else if (action == 'unplace') {
                            game.removeItemFromProperty(item);
                            _showMessage(context, l10n.removedFromStudio);
                          } else if (action == 'sell') {
                            final sold = game.quickSell(item);
                            if (sold) unawaited(HapticFeedback.mediumImpact());
                            _showMessage(context, sold ? l10n.soldFor(money((item.value * .65).round())) : l10n.removeBeforeSelling);
                          } else if (action == 'auction') {
                            showCreateListing(context, game, item: item);
                          }
                        },
                        itemBuilder: (_) => [
                          if (item.placed)
                            PopupMenuItem(value: 'unplace', child: Text(l10n.removeFromStudio))
                          else ...[
                            PopupMenuItem(value: 'place', child: Text(l10n.placeInStudio)),
                            PopupMenuItem(value: 'auction', child: Text(l10n.listForAuction)),
                            PopupMenuItem(value: 'sell', child: Text(l10n.quickSell)),
                          ],
                        ],
                      ),
                    ]),
                  ),
                )),
          const SizedBox(height: 8),
          glassCard(child: Row(children: [
            const Icon(Icons.tips_and_updates_rounded, color: _cyan),
            const SizedBox(width: 10),
            Expanded(child: Text(l10n.propertyPrestigeHint, style: const TextStyle(color: _muted, fontSize: 12))),
          ])),
        ],
      );
  }
}

Future<void> showCreateListing(BuildContext context, GameState game, {GameItem? item}) async {
  final l10n = AppLocalizations.of(context)!;
  final available = item == null ? game.inventory.where((asset) => !asset.placed).toList() : [item];
  final properties = item == null && game.placedCount == 0
      ? game.properties
      : const <GameProperty>[];
  if (available.isEmpty && properties.isEmpty) {
    _showMessage(
      context,
      game.placedCount > 0 && game.properties.isNotEmpty
          ? l10n.removeBeforeListingProperty
          : l10n.nothingToList,
    );
    return;
  }
  final selection = await showDialog<_ListingSelection>(
    context: context,
    builder: (_) =>
        CreateListingDialog(items: available, properties: properties),
  );
  if (selection == null || !context.mounted) return;
  final success = selection.item != null
      ? game.createListing(
          selection.item!,
          selection.mode,
          selection.price,
          duration: selection.duration,
        )
      : selection.property != null &&
          game.createPropertyListing(
            selection.property!,
            selection.mode,
            selection.price,
            duration: selection.duration,
          );
  _showMessage(
    context,
    success
        ? l10n.auctionCreated(_auctionModeLabel(l10n, selection.mode))
        : l10n.couldNotCreateListing,
  );
}

class _ListingSelection {
  const _ListingSelection({
    this.item,
    this.property,
    required this.mode,
    required this.price,
    required this.duration,
  });
  final GameItem? item;
  final GameProperty? property;
  final AuctionMode mode;
  final int price;
  final Duration duration;
}

class CreateListingDialog extends StatefulWidget {
  const CreateListingDialog({
    required this.items,
    required this.properties,
    super.key,
  });
  final List<GameItem> items;
  final List<GameProperty> properties;

  @override
  State<CreateListingDialog> createState() => _CreateListingDialogState();
}

class _CreateListingDialogState extends State<CreateListingDialog> {
  late bool listingProperty =
      widget.items.isEmpty && widget.properties.isNotEmpty;
  late GameItem? item = widget.items.isEmpty ? null : widget.items.first;
  late GameProperty? property =
      widget.properties.isEmpty ? null : widget.properties.first;
  AuctionMode mode = AuctionMode.english;
  String durationLabel = '1 hour';
  late final TextEditingController price = TextEditingController(
    text: '${item?.value ?? property?.value ?? ''}',
  );
  static const durations = {
    '1 hour': Duration(hours: 1),
    '6 hours': Duration(hours: 6),
    '24 hours': Duration(hours: 24),
  };

  @override
  void dispose() {
    price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
        title: Text(l10n.createAuction),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (widget.items.isNotEmpty && widget.properties.isNotEmpty)
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(l10n.item)),
                ButtonSegment(value: true, label: Text(l10n.property)),
              ],
              selected: {listingProperty},
              onSelectionChanged: (selection) => setState(() {
                listingProperty = selection.first;
                price.text = listingProperty
                    ? '${property?.value ?? ''}'
                    : '${item?.value ?? ''}';
              }),
            ),
          if (listingProperty)
            DropdownButtonFormField<GameProperty>(
              value: property,
              decoration: InputDecoration(labelText: l10n.property),
              items: widget.properties
                  .map((ownedProperty) => DropdownMenuItem(
                        value: ownedProperty,
                        child: Text(_localizedPropertyName(l10n, ownedProperty.name),
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (value) => setState(() {
                property = value;
                price.text = '${value?.value ?? ''}';
              }),
            )
          else
            DropdownButtonFormField<GameItem>(
              value: item,
              decoration: InputDecoration(labelText: l10n.item),
              items: widget.items
                  .map((asset) => DropdownMenuItem(
                        value: asset,
                        child: Text(_localizedItemName(l10n, asset.name),
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (value) => setState(() {
                item = value;
                price.text = '${value?.value ?? ''}';
              }),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<AuctionMode>(
            value: mode,
            decoration: InputDecoration(labelText: l10n.auctionFormat),
            items: AuctionMode.values.map((option) => DropdownMenuItem(value: option, child: Text(_auctionModeLabel(l10n, option)))).toList(),
            onChanged: (value) => setState(() => mode = value!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: durationLabel,
            decoration: InputDecoration(labelText: l10n.duration),
            items: durations.keys.map((value) => DropdownMenuItem(value: value, child: Text(switch (value) {
              '1 hour' => l10n.oneHour,
              '6 hours' => l10n.sixHours,
              _ => l10n.twentyFourHours,
            }))).toList(),
            onChanged: (value) => setState(() => durationLabel = value!),
          ),
          const SizedBox(height: 12),
          TextField(controller: price, keyboardType: TextInputType.number, decoration: InputDecoration(prefixText: '\$ ', labelText: l10n.startingPriceLabel)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(price.text);
              if (parsed == null ||
                  parsed <= 0 ||
                  (listingProperty ? property == null : item == null)) {
                return;
              }
              Navigator.pop(
                context,
                _ListingSelection(
                  item: listingProperty ? null : item,
                  property: listingProperty ? property : null,
                  mode: mode,
                  price: parsed,
                  duration: durations[durationLabel]!,
                ),
              );
            },
            child: Text(listingProperty ? l10n.listProperty : l10n.listItem),
          ),
        ],
      );
  }
}

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({required this.game, this.rewardedAds, super.key});
  final GameState game;
  final RewardedAdService? rewardedAds;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
        padding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width >= 760 ? 32 : 18, 20, MediaQuery.sizeOf(context).width >= 760 ? 32 : 18, 28),
        children: [
          glassCard(
            child: Row(children: [
              Expanded(child: _balanceColumn(l10n.availableCash, money(game.cash), _gold, Icons.payments_rounded)),
              Container(width: 1, height: 48, color: Colors.white12),
              Expanded(child: _balanceColumn(l10n.diamonds, '${game.diamonds}', _cyan, Icons.diamond_rounded)),
            ]),
          ),
          const SizedBox(height: 18),
          sectionTitle(
            l10n.earnRewards,
            trailing: l10n.claimsLeft(
              game.dailyRewardLimit - game.dailyRewardClaims,
            ),
          ),
          Text(
            rewardedAds == null
                ? l10n.simulateReward
                : l10n.watchReward,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _rewardTile(
            context: context,
            icon: Icons.account_balance_rounded,
            title: l10n.cashBoost,
            subtitle: l10n.cashRewardSubtitle(game.dailyRewardLimit),
            color: _gold,
            claimed: false,
            enabled: game.dailyRewardClaims < game.dailyRewardLimit,
            disabledLabel: l10n.limit,
            onTap: () => _reward(context, game, rewardedAds, 'cash', 2500, 0),
          ),
          const SizedBox(height: 10),
          _rewardTile(
            context: context,
            icon: Icons.diamond_rounded,
            title: l10n.diamondDrop,
            subtitle: l10n.diamondRewardSubtitle(game.dailyRewardLimit),
            color: _cyan,
            claimed: false,
            enabled: game.dailyRewardClaims < game.dailyRewardLimit,
            disabledLabel: l10n.limit,
            onTap: () => _reward(context, game, rewardedAds, 'diamonds', 0, 5),
          ),
          const SizedBox(height: 10),
          _rewardTile(
            context: context,
            icon: Icons.home_work_rounded,
            title: l10n.instantRent,
            subtitle: l10n.instantRentSubtitle,
            color: _green,
            claimed: game.claimedRewards.contains('rent'),
            enabled: !game.claimedRewards.contains('rent') &&
                game.properties.isNotEmpty,
            disabledLabel: l10n.unavailable,
            onTap: () => _reward(context, game, rewardedAds, 'rent', 420, 0),
          ),
          const SizedBox(height: 20),
          glassCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline_rounded, color: _muted, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                rewardedAds == null
                    ? l10n.demoRewardsNotice
                    : l10n.realRewardsNotice,
                style: const TextStyle(color: _muted, fontSize: 11, height: 1.5),
              ),
            ),
          ])),
        ],
      );
  }
}

Widget _balanceColumn(String title, String value, Color color, IconData icon) => Column(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 8),
      Text(title, style: const TextStyle(color: _muted, fontSize: 9, letterSpacing: 1)),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
    ]);

Widget _rewardTile({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String subtitle,
  required Color color,
  required bool claimed,
  required bool enabled,
  required VoidCallback onTap,
  String disabledLabel = 'Limit',
}) =>
    glassCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(width: 46, height: 46, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: _muted, fontSize: 11)),
        ])),
        if (claimed)
          const Icon(Icons.check_circle_rounded, color: _green)
        else if (!enabled)
          Text(disabledLabel,
              style: const TextStyle(
                  color: _muted, fontSize: 10, fontWeight: FontWeight.w700))
        else
          OutlinedButton(onPressed: onTap, style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color.withValues(alpha: .5))), child: Text(AppLocalizations.of(context)!.watch)),
      ]),
    );

Future<void> _reward(
  BuildContext context,
  GameState game,
  RewardedAdService? rewardedAds,
  String id,
  int cash,
  int diamonds,
) async {
  final l10n = AppLocalizations.of(context)!;
  var earned = true;
  if (id != 'rent' && rewardedAds != null) {
    try {
      earned = await rewardedAds.showRewardedAd();
    } catch (error) {
      if (context.mounted) _showMessage(context, l10n.adLoadError(error.toString()));
      return;
    }
  }
  if (!context.mounted) return;
  final claimed = earned &&
      (id == 'rent'
          ? game.claimRentReward()
          : game.claimReward(
              '$id-${game.dailyRewardClaims}',
              cashReward: cash,
              diamondReward: diamonds,
            ));
  if (claimed) unawaited(HapticFeedback.mediumImpact());
  _showMessage(
    context,
    !earned
        ? l10n.watchFullAd
        : claimed
            ? l10n.rewardClaimed
            : l10n.dailyRewardLimitReached,
  );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.game,
    this.authService,
    super.key,
  });
  final GameState game;
  final AuthService? authService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final Stream<UserAccount?>? accountStream;

  @override
  void initState() {
    super.initState();
    accountStream = widget.authService?.watchCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
        padding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width >= 760 ? 32 : 18, 20, MediaQuery.sizeOf(context).width >= 760 ? 32 : 18, 28),
        children: [
          StreamBuilder<UserAccount?>(
            stream: accountStream,
            builder: (context, snapshot) {
              final account = snapshot.data;
              return glassCard(
                child: Column(children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _gold.withValues(alpha: .15),
                      border: Border.all(color: _gold.withValues(alpha: .5)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: account != null && account.photoUrl.isNotEmpty
                        ? Image.network(
                            account.photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person_rounded,
                              color: _gold,
                              size: 40,
                            ),
                          )
                        : const Icon(
                            Icons.person_rounded,
                            color: _gold,
                            size: 40,
                          ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    account?.displayName ?? l10n.empireBuilder,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    account?.email ??
                        (widget.authService == null
                            ? l10n.demoProfile
                            : l10n.signInToSync),
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(child: _stat(l10n.netWorth, money(widget.game.netWorth), _gold)),
                    Expanded(
                      child: _stat(
                        l10n.properties,
                        '${widget.game.properties.length}',
                        _cyan,
                      ),
                    ),
                    Expanded(child: _stat(l10n.items, '${widget.game.inventory.length}', _green)),
                  ]),
                ]),
              );
            },
          ),
          if (widget.authService != null) ...[
            const SizedBox(height: 12),
            StreamBuilder<UserAccount?>(
              stream: accountStream,
              builder: (context, snapshot) {
                final account = snapshot.data;
                return glassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.account_circle_rounded, color: _cyan),
                    title: Text(account?.displayName ?? l10n.connectGoogle),
                    subtitle: Text(
                      snapshot.hasError
                          ? l10n.couldNotLoadAccount(snapshot.error.toString())
                          : account?.email ?? l10n.syncWithFirebase,
                    ),
                    trailing: TextButton(
                      onPressed: snapshot.connectionState == ConnectionState.waiting
                          ? null
                          : () => _toggleAccount(context, widget.authService!, account),
                      child: Text(account == null ? l10n.signIn : l10n.signOut),
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 18),
          sectionTitle(l10n.friends),
          glassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0x223FC7D9),
                child: Icon(Icons.group_rounded, color: _cyan),
              ),
              title: Text(l10n.friends),
              subtitle: Text(l10n.noFriendsYet),
              trailing: IconButton(
                tooltip: l10n.addFriend,
                onPressed: () => _showMessage(context, l10n.friendListComingSoon),
                icon: const Icon(Icons.person_add_alt_1_rounded, color: _cyan),
              ),
            ),
          ),
          const SizedBox(height: 12),
          glassCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.school_rounded, color: _gold),
              title: Text(l10n.howToPlay),
              subtitle: Text(l10n.learnToTrade),
              trailing: const Icon(Icons.chevron_right_rounded, color: _muted),
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.buildEmpire),
                  content: Text(l10n.tutorialSteps),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.letsGo))],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text(l10n.demoBuild, style: const TextStyle(color: _muted, fontSize: 9, letterSpacing: 1.4))),
        ],
      );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.onLocaleChanged, super.key});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool sound = true;
  bool haptics = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width >= 760 ? 32 : 18, 20, MediaQuery.sizeOf(context).width >= 760 ? 32 : 18, 28),
      children: [
        sectionTitle(l10n.preferences),
        glassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.soundEffects),
              secondary: const Icon(Icons.volume_up_rounded, color: _muted),
              value: sound,
              onChanged: (value) => setState(() => sound = value),
            ),
            const Divider(height: 1, color: Color(0xFF2A3040)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.hapticFeedback),
              secondary: const Icon(Icons.vibration_rounded, color: _muted),
              value: haptics,
              onChanged: (value) => setState(() => haptics = value),
            ),
            const Divider(height: 1, color: Color(0xFF2A3040)),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.translate_rounded, color: _muted),
              title: Text(l10n.language),
              trailing: DropdownButton<Locale>(
                value: locale,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(value: const Locale('en'), child: Text(l10n.english)),
                  DropdownMenuItem(value: const Locale('he'), child: Text(l10n.hebrew)),
                ],
                onChanged: (value) {
                  if (value != null) widget.onLocaleChanged(value);
                },
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

Future<void> _toggleAccount(
  BuildContext context,
  AuthService authService,
  UserAccount? account,
) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    if (account == null) {
      await authService.signInWithGoogle();
    } else {
      await authService.signOut();
    }
  } catch (error) {
    if (context.mounted) _showMessage(context, l10n.accountActionFailed(error.toString()));
  }
}

Widget _stat(String label, String value, Color color) => Column(children: [
      Text(label, style: const TextStyle(color: _muted, fontSize: 8, letterSpacing: .7)),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14, fontFeatures: const [FontFeature.tabularFigures()])),
    ]);

String _auctionModeLabel(AppLocalizations l10n, AuctionMode mode) =>
    switch (mode) {
      AuctionMode.english => l10n.auctionModeEnglish,
      AuctionMode.dutch => l10n.auctionModeDutch,
      AuctionMode.sealedBid => l10n.auctionModeSealed,
      AuctionMode.vickrey => l10n.auctionModeVickrey,
    };

String _localizedCategory(AppLocalizations l10n, String category) =>
    localizedCategory(l10n, category);

String _localizedRarity(AppLocalizations l10n, String rarity) =>
    localizedRarity(l10n, rarity);

String _localizedItemName(AppLocalizations l10n, String name) =>
    localizedItemName(l10n, name);

String _localizedPropertyName(AppLocalizations l10n, String name) =>
    localizedPropertyName(l10n, name);

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
}
