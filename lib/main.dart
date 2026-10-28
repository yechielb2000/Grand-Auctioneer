import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
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
import 'game_state.dart';
import 'services/ads/rewarded_ad_service.dart';

const _background = AppColors.background;
const _surface = AppColors.surface;
const _gold = AppColors.primaryGold;
const _green = AppColors.accentGreen;
const _cyan = AppColors.diamondCyan;
const _muted = AppColors.textSecondary;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final rewardedAds = AppConfig.adsEnabled
      ? RewardedAdService(AppConfig.rewardedAdUnitId)
      : null;
  if (rewardedAds != null) await rewardedAds.initialize();

  AppServices? services;
  if (AppConfig.firebaseEnabled) {
    await Firebase.initializeApp();
    services = await AppServices.initialize();
  }

  runApp(AuctionEmpireApp(services: services, rewardedAds: rewardedAds));
}

class AuctionEmpireApp extends StatefulWidget {
  const AuctionEmpireApp({this.services, this.rewardedAds, super.key});

  final AppServices? services;
  final RewardedAdService? rewardedAds;

  @override
  State<AuctionEmpireApp> createState() => _AuctionEmpireAppState();
}

class _AuctionEmpireAppState extends State<AuctionEmpireApp> {
  late final GameState game;

  @override
  void initState() {
    super.initState();
    final remoteConfig = widget.services?.remoteConfig;
    game = GameState(
      auctionExtension: Duration(
        seconds: remoteConfig?.auctionExtensionSeconds ?? 15,
      ),
      dailyRewardLimit: remoteConfig?.dailyRewardLimit ?? 5,
    );
  }

  @override
  void dispose() {
    game.dispose();
    if (widget.services != null) unawaited(widget.services!.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: game,
        builder: (context, _) => MaterialApp(
          title: 'Auction Empire',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: _background,
            colorScheme: const ColorScheme.dark(
              primary: _gold,
              secondary: _green,
              surface: _surface,
              error: AppColors.accentRed,
            ),
            fontFamily: 'Roboto',
            useMaterial3: true,
          ),
          navigatorObservers: widget.services == null
              ? const []
              : [
                  FirebaseAnalyticsObserver(
                    analytics: widget.services!.analytics,
                  ),
                ],
          home: GameHome(
            game: game,
            services: widget.services,
            rewardedAds: widget.rewardedAds,
          ),
        ),
      );
}

class GameHome extends StatefulWidget {
  const GameHome({
    required this.game,
    required this.services,
    required this.rewardedAds,
    super.key,
  });

  final GameState game;
  final AppServices? services;
  final RewardedAdService? rewardedAds;

  @override
  State<GameHome> createState() => _GameHomeState();
}

class _GameHomeState extends State<GameHome> {
  int selectedTab = 0;
  final pages = const ['World', 'Auction House', 'My Assets', 'Bank & Rewards', 'Profile'];
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
            context: const ErrorDescription(
              'while listening for foreground auction notifications',
            ),
          ),
        );
      },
    );
  }

  void _showOutbidMessage(RemoteMessage message) {
    if (message.data['type'] != 'outbid') return;
    final title = message.notification?.title ?? 'You have been outbid';
    final body = message.notification?.body ??
        message.data['body']?.toString() ??
        'Another player placed a higher bid.';
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
    final game = widget.game;
    final screens = [
      MapScreen(game: game),
      AuctionScreen(game: game, isActive: selectedTab == 1),
      InventoryScreen(game: game),
      RewardsScreen(game: game, rewardedAds: widget.rewardedAds),
      ProfileScreen(game: game, authService: widget.services?.auth),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _background,
        titleSpacing: 18,
        title: Row(
          children: [
            const AppIcon(
              assetName: AppAssets.gem,
              color: _cyan,
              size: 23,
              semanticLabel: 'Gems',
            ),
            const SizedBox(width: 8),
            Text(pages[selectedTab], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          CurrencyPill(assetName: AppAssets.cash, color: _gold, text: money(game.cash)),
          const SizedBox(width: 7),
          CurrencyPill(assetName: AppAssets.gem, color: _cyan, text: '${game.diamonds}'),
          const SizedBox(width: 14),
        ],
      ),
      body: SafeArea(
        top: false,
        child: IndexedStack(index: selectedTab, children: screens),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() => selectedTab = index);
          final analytics = widget.services?.analytics;
          if (analytics != null) {
            unawaited(_logScreenView(analytics, pages[index]));
          }
        },
        destinations: const [
          NavigationDestination(
            icon: AppIcon(assetName: AppAssets.map, color: AppColors.textSecondary),
            selectedIcon: AppIcon(assetName: AppAssets.map, color: _gold),
            label: 'Map',
          ),
          NavigationDestination(
            icon: AppIcon(assetName: AppAssets.market, color: AppColors.textSecondary),
            selectedIcon: AppIcon(assetName: AppAssets.market, color: _gold),
            label: 'Auctions',
          ),
          NavigationDestination(
            icon: AppIcon(assetName: AppAssets.warehouse, color: AppColors.textSecondary),
            selectedIcon: AppIcon(assetName: AppAssets.warehouse, color: _gold),
            label: 'Assets',
          ),
          NavigationDestination(
            icon: AppIcon(assetName: AppAssets.cash, color: AppColors.textSecondary),
            selectedIcon: AppIcon(assetName: AppAssets.cash, color: _gold),
            label: 'Bank',
          ),
          NavigationDestination(
            icon: AppIcon(assetName: AppAssets.profile, color: AppColors.textSecondary),
            selectedIcon: AppIcon(assetName: AppAssets.profile, color: _gold),
            label: 'Profile',
          ),
        ],
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
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
        if (trailing != null) Text(trailing, style: const TextStyle(color: _muted, fontSize: 12)),
      ]),
    );

Widget glassCard({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) => Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderGlass),
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
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(children: [
            const Expanded(child: Text('Your empire starts here', style: TextStyle(color: _muted))),
            const Icon(Icons.my_location_rounded, color: _cyan, size: 17),
            const SizedBox(width: 5),
            const Text('SUBURBS', style: TextStyle(color: _cyan, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 330,
              child: InteractiveViewer(
                minScale: .75,
                maxScale: 2.8,
                boundaryMargin: const EdgeInsets.all(80),
                child: Container(
                  width: 580,
                  height: 400,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF192A2B), Color(0xFF19212B), Color(0xFF282535)]),
                  ),
                  child: Stack(children: [
                    Positioned(left: 30, top: 42, child: _mapDistrict('SUBURBS', Icons.park_rounded, const Color(0xFF28423C))),
                    Positioned(left: 265, top: 28, child: _mapDistrict('DOWNTOWN', Icons.location_city_rounded, const Color(0xFF31394B))),
                    Positioned(left: 340, top: 242, child: _mapDistrict('MARINA', Icons.sailing_rounded, const Color(0xFF263D50))),
                    Positioned(
                      left: 78,
                      top: 200,
                      child: _mapProperty(
                        game.properties.isEmpty
                            ? 'Available shed'
                            : game.properties.first.name,
                        game.properties.isNotEmpty,
                        PropertyArtStyle.shed,
                        onTap: game.properties.isEmpty
                            ? null
                            : () => showPropertySlots(context, game),
                      ),
                    ),
                    Positioned(
                      left: 270,
                      top: 166,
                      child: _mapProperty(
                        'Available apartment',
                        false,
                        PropertyArtStyle.apartment,
                      ),
                    ),
                    Positioned(
                      left: 430,
                      top: 70,
                      child: _mapProperty(
                        'Villa district',
                        false,
                        PropertyArtStyle.villa,
                      ),
                    ),
                    Positioned(
                      left: 462,
                      top: 235,
                      child: _mapProperty(
                        'Marina',
                        false,
                        PropertyArtStyle.marina,
                      ),
                    ),
                    Positioned(left: 100, top: 154, child: Transform.rotate(angle: -.45, child: Container(width: 210, height: 15, color: const Color(0xFF4A4D47)))),
                    Positioned(left: 322, top: 65, child: Transform.rotate(angle: 1.1, child: Container(width: 255, height: 13, color: const Color(0xFF4A4D47)))),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (game.properties.isNotEmpty)
            glassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 46, height: 46, decoration: BoxDecoration(color: _gold.withValues(alpha: .13), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.apartment_rounded, color: _gold)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(game.properties.first.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text(
                    'Your starter property · ${game.properties.first.furnitureSlots} furniture · ${game.properties.first.vehicleSlots} vehicle slots',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ])),
                const Icon(Icons.verified_rounded, color: _green, size: 20),
              ]),
              const Divider(height: 25, color: Color(0xFF2A3040)),
              Row(children: [
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('PASSIVE RENT', style: TextStyle(color: _muted, fontSize: 10, letterSpacing: 1.2)),
                  SizedBox(height: 4),
                  Text('\$420 / hour', style: TextStyle(color: _gold, fontWeight: FontWeight.w700)),
                ])),
                primaryButton(label: 'Collect rent', icon: Icons.attach_money_rounded, onPressed: game.collectRent),
              ]),
              const SizedBox(height: 12),
              Text(
                '${game.placedFurnitureCount}/${game.properties.first.furnitureSlots} furniture · ${game.placedVehicleCount}/${game.properties.first.vehicleSlots} vehicle slots used',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 7),
              LinearProgressIndicator(
                value: (game.placedFurnitureCount +
                        game.placedVehicleCount) /
                    (game.properties.first.furnitureSlots +
                        game.properties.first.vehicleSlots),
                minHeight: 5,
                borderRadius: BorderRadius.circular(9),
                color: _gold,
                backgroundColor: const Color(0xFF2A3040),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => showPropertySlots(context, game),
                  icon: const Icon(Icons.grid_view_rounded, size: 17),
                  label: const Text('Open property slots'),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          const Text('Pinch to zoom · drag to explore districts', textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 11)),
        ],
      );
}

Widget _mapDistrict(String name, IconData icon, Color color) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: .8), borderRadius: BorderRadius.circular(15)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white70, size: 17), const SizedBox(width: 6), Text(name, style: const TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w700))]),
    );

Widget _mapProperty(
  String label,
  bool owned,
  PropertyArtStyle style, {
  VoidCallback? onTap,
}) =>
    InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Semantics(
        label: '$label${owned ? ', owned property' : ''}',
        button: onTap != null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IsometricPropertyArt(style: style, size: 78),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                color: owned ? _gold : Colors.white70,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

Future<void> showPropertySlots(BuildContext context, GameState game) async {
  if (game.properties.isEmpty) return;
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
              Text(property.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Tap an empty slot to place an item from your warehouse.',
                  style: TextStyle(color: _muted, fontSize: 12)),
              const SizedBox(height: 14),
              _propertySlotSection(
                context,
                game,
                'Furniture',
                property.furnitureSlots,
                (item) => item.category != 'Vehicles' &&
                    item.category != 'Boats',
                Icons.chair_rounded,
              ),
              const SizedBox(height: 12),
              _propertySlotSection(
                context,
                game,
                'Vehicles',
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
                        category: item.category,
                        size: 42,
                        semanticLabel: item.name,
                      ),
                title: Text(item?.name ?? 'Empty $category slot'),
                subtitle: Text(item == null
                    ? 'Assign from your warehouse'
                    : '${item.rarity} · ${item.category}'),
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
                        'No matching items in your warehouse.',
                      );
                      return;
                    }
                    final selected = await showDialog<GameItem>(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: Text('Choose $category item'),
                        children: available
                            .map((candidate) => SimpleDialogOption(
                                  onPressed: () =>
                                      Navigator.pop(context, candidate),
                                  child: Text(candidate.name),
                                ))
                            .toList(),
                      ),
                    );
                    if (selected != null && context.mounted) {
                      _showMessage(
                        context,
                        game.placeItem(selected)
                            ? 'Item assigned to your property.'
                            : 'No matching property slot is available.',
                      );
                    }
                    return;
                  }

                  if (!context.mounted) return;
                  final remove = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(item.name),
                      content: Text(
                        '${item.rarity} ${item.category.toLowerCase()} currently placed in your property.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Keep placed'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Return to warehouse'),
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
    final auctions = widget.game.auctions
        .where((auction) =>
            (auction.resolved || !auction.isExpired) &&
            (filter == null || auction.mode == filter))
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(children: [
          const Expanded(child: Text('Live marketplace', style: TextStyle(color: _muted))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: const Color(0xFF3B1821), borderRadius: BorderRadius.circular(20)), child: const Row(children: [Icon(Icons.circle, size: 7, color: Color(0xFFFF5470)), SizedBox(width: 6), Text('LIVE', style: TextStyle(color: Color(0xFFFF7184), fontSize: 10, fontWeight: FontWeight.w800))])),
        ]),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _filterChip('All modes', filter == null, () => setState(() => filter = null)),
            ...AuctionMode.values.map((mode) => Padding(
                  padding: const EdgeInsets.only(left: 7),
                  child: _filterChip(mode.label, filter == mode, () => setState(() => filter = mode)),
                )),
          ]),
        ),
        const SizedBox(height: 16),
        sectionTitle('Ending soon', trailing: '${auctions.length} listings'),
        if (auctions.isEmpty)
          glassCard(child: const Center(child: Text('No active auctions for this filter.', style: TextStyle(color: _muted))))
        else
          ...auctions.map((auction) => Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: AuctionCard(auction: auction, game: widget.game),
              )),
        const SizedBox(height: 7),
        sectionTitle('List an item or property'),
        glassCard(
          child: Row(children: [
            const Icon(Icons.sell_rounded, color: _gold, size: 30),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Turn your assets into cash', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('Choose an item or property and auction format.', style: TextStyle(color: _muted, fontSize: 12)),
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
    final price = auction.currentPrice;
    return glassCard(
      padding: const EdgeInsets.all(15),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GameItemArtwork(
            icon: auction.icon,
            size: 52,
            semanticLabel: auction.itemName,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(auction.itemName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 5),
            Text(auction.mode.label.toUpperCase(), style: const TextStyle(color: _cyan, fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w800)),
          ])),
          _countdown(auction.endsAt),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              auction.mode == AuctionMode.dutch
                  ? 'CURRENT PRICE'
                  : auction.mode == AuctionMode.sealedBid ||
                          auction.mode == AuctionMode.vickrey
                      ? 'STARTING PRICE'
                      : 'CURRENT BID',
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
            Text('${auction.bids} bids', style: const TextStyle(color: _muted, fontSize: 11)),
          const SizedBox(width: 10),
          if (auction.resolved)
            const Chip(
                label: Text('ENDED'),
                visualDensity: VisualDensity.compact,
                labelStyle: TextStyle(color: _muted, fontSize: 9))
          else if (auction.isPlayerListing)
            const Chip(
                label: Text('YOUR LISTING'),
                visualDensity: VisualDensity.compact,
                labelStyle: TextStyle(color: _cyan, fontSize: 9))
          else if (auction.myBid != null &&
              auction.mode != AuctionMode.english)
            const Chip(label: Text('BID PLACED'), visualDensity: VisualDensity.compact, labelStyle: TextStyle(color: _cyan, fontSize: 9))
          else
            primaryButton(
              label: auction.mode == AuctionMode.dutch ? 'Buy now' : 'Place bid',
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
                          'Not enough cash to claim this item.',
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
                  ? 'Bids stay sealed until the timer expires.'
                  : 'Your sealed bid is ${money(auction.myBid!)}. All bids reveal when the timer expires.',
              style: const TextStyle(color: _muted, fontSize: 10),
            )
          else ...[
            Text(
              'Revealed bids: ${(auction.revealedBids ?? const <int>[]).map(money).join(' · ')}',
              style: const TextStyle(color: _muted, fontSize: 10),
            ),
            const SizedBox(height: 5),
            Text(
              auction.playerWon == true
                  ? 'You won for ${money(auction.clearingPrice ?? auction.startingPrice)}.'
                  : auction.winningBid == null
                      ? 'No bids were placed.'
                      : 'Auction ended · winning bid ${money(auction.winningBid!)}.',
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
                ? 'You won for ${money(auction.clearingPrice ?? auction.startingPrice)}.'
                : auction.isPlayerListing
                    ? 'Listing ended. The item or property was returned to your assets.'
                    : 'Auction ended.',
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
  Widget build(BuildContext context) => Dialog(
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
              const Text(
                'YOU WON!',
                style: TextStyle(
                  color: _gold,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.itemName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Winning price · ${money(widget.price)}',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: primaryButton(
                  label: 'Continue',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      );
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

Widget _countdown(DateTime end) {
  final remaining = end.difference(DateTime.now());
  if (remaining.isNegative) return const Text('ENDED', style: TextStyle(color: _muted, fontSize: 10));
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
  return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
    const Text('ENDS IN', style: TextStyle(color: _muted, fontSize: 8, letterSpacing: 1)),
    const SizedBox(height: 3),
    Text(hours > 0 ? '${hours}h $minutes' : '$minutes:$seconds', style: const TextStyle(color: Color(0xFFFF7184), fontSize: 12, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
  ]);
}

Future<void> showBidDialog(BuildContext context, GameState game, GameAuction auction) async {
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
  _showMessage(context, placed ? 'Your bid was placed.' : 'Bid was rejected. Check your balance and minimum bid.');
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
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.sealed ? 'Submit sealed bid' : 'Place your bid'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Minimum ${money(widget.minimum)} · balance ${money(widget.balance)}', style: const TextStyle(color: _muted, fontSize: 12)),
          if (widget.sealed) ...[
            const SizedBox(height: 8),
            const Text(
              'Your amount remains hidden from the marketplace until the auction ends.',
              style: TextStyle(color: _cyan, fontSize: 11),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: input,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(prefixText: '\$ ', labelText: 'Your bid', border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, int.tryParse(input.text)),
              child: Text(widget.sealed ? 'Seal bid' : 'Confirm bid')),
        ],
      );
}

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({required this.game, super.key});
  final GameState game;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(children: [
            Expanded(child: Text('${game.inventory.length} items ready to trade', style: const TextStyle(color: _muted))),
            const Icon(Icons.warehouse_rounded, color: _gold, size: 18),
            const SizedBox(width: 5),
            const Text('4 / 20 SLOTS', style: TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          if (game.inventory.isEmpty)
            glassCard(child: const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Your warehouse is empty. Win an auction or collect a reward to get started.', textAlign: TextAlign.center, style: TextStyle(color: _muted)))))
          else
            ...game.inventory.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: glassCard(
                    padding: const EdgeInsets.all(13),
                    child: Row(children: [
                      GameItemArtwork(
                        icon: item.icon,
                        category: item.category,
                        semanticLabel: item.name,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('${item.rarity} · ${item.category}', style: const TextStyle(color: _muted, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text('Est. value ${money(item.value)}', style: const TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w600)),
                      ])),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: _muted),
                        onSelected: (action) {
                          if (action == 'place') {
                            final placed = game.placeItem(item);
                            _showMessage(context, placed ? 'Placed in your studio.' : 'All property display slots are in use.');
                          } else if (action == 'unplace') {
                            game.removeItemFromProperty(item);
                            _showMessage(context, 'Removed from your studio.');
                          } else if (action == 'sell') {
                            final sold = game.quickSell(item);
                            if (sold) unawaited(HapticFeedback.mediumImpact());
                            _showMessage(context, sold ? 'Sold for ${money((item.value * .65).round())}.' : 'Remove this item from your studio before selling.');
                          } else if (action == 'auction') {
                            showCreateListing(context, game, item: item);
                          }
                        },
                        itemBuilder: (_) => [
                          if (item.placed)
                            const PopupMenuItem(value: 'unplace', child: Text('Remove from studio'))
                          else ...[
                            const PopupMenuItem(value: 'place', child: Text('Place in studio')),
                            const PopupMenuItem(value: 'auction', child: Text('List for auction')),
                            const PopupMenuItem(value: 'sell', child: Text('Quick sell · 65%')),
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
            const Expanded(child: Text('Display rare items in your property to increase prestige and rental income.', style: TextStyle(color: _muted, fontSize: 12))),
          ])),
        ],
      );
}

Future<void> showCreateListing(BuildContext context, GameState game, {GameItem? item}) async {
  final available = item == null ? game.inventory.where((asset) => !asset.placed).toList() : [item];
  final properties = item == null && game.placedCount == 0
      ? game.properties
      : const <GameProperty>[];
  if (available.isEmpty && properties.isEmpty) {
    _showMessage(
      context,
      game.placedCount > 0 && game.properties.isNotEmpty
          ? 'Remove displayed items before listing your property.'
          : 'No available items or properties to list.',
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
  _showMessage(context, success ? 'Your ${selection.mode.label} auction is live.' : 'Could not create listing.');
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
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Create auction'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (widget.items.isNotEmpty && widget.properties.isNotEmpty)
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Item')),
                ButtonSegment(value: true, label: Text('Property')),
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
              decoration: const InputDecoration(labelText: 'Property'),
              items: widget.properties
                  .map((ownedProperty) => DropdownMenuItem(
                        value: ownedProperty,
                        child: Text(ownedProperty.name,
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
              decoration: const InputDecoration(labelText: 'Item'),
              items: widget.items
                  .map((asset) => DropdownMenuItem(
                        value: asset,
                        child: Text(asset.name,
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
            decoration: const InputDecoration(labelText: 'Auction format'),
            items: AuctionMode.values.map((option) => DropdownMenuItem(value: option, child: Text(option.label))).toList(),
            onChanged: (value) => setState(() => mode = value!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: durationLabel,
            decoration: const InputDecoration(labelText: 'Duration'),
            items: durations.keys.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
            onChanged: (value) => setState(() => durationLabel = value!),
          ),
          const SizedBox(height: 12),
          TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(prefixText: '\$ ', labelText: 'Starting price')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
            child: Text(listingProperty ? 'List property' : 'List item'),
          ),
        ],
      );
}

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({required this.game, this.rewardedAds, super.key});
  final GameState game;
  final RewardedAdService? rewardedAds;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          glassCard(
            child: Row(children: [
              Expanded(child: _balanceColumn('AVAILABLE CASH', money(game.cash), _gold, Icons.payments_rounded)),
              Container(width: 1, height: 48, color: Colors.white12),
              Expanded(child: _balanceColumn('DIAMONDS', '${game.diamonds}', _cyan, Icons.diamond_rounded)),
            ]),
          ),
          const SizedBox(height: 18),
          sectionTitle(
            'Earn rewards',
            trailing:
                '${game.dailyRewardLimit - game.dailyRewardClaims} claims left this session',
          ),
          Text(
            rewardedAds == null
                ? 'Choose a reward to simulate a completed rewarded video.'
                : 'Watch a rewarded video to claim cash or diamonds.',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _rewardTile(
            icon: Icons.account_balance_rounded,
            title: 'Cash boost',
            subtitle: '+\$2,500 cash · up to ${game.dailyRewardLimit} per session',
            color: _gold,
            claimed: false,
            enabled: game.dailyRewardClaims < game.dailyRewardLimit,
            disabledLabel: 'Limit',
            onTap: () => _reward(context, game, rewardedAds, 'cash', 2500, 0),
          ),
          const SizedBox(height: 10),
          _rewardTile(
            icon: Icons.diamond_rounded,
            title: 'Diamond drop',
            subtitle: '+5 diamonds · up to ${game.dailyRewardLimit} per session',
            color: _cyan,
            claimed: false,
            enabled: game.dailyRewardClaims < game.dailyRewardLimit,
            disabledLabel: 'Limit',
            onTap: () => _reward(context, game, rewardedAds, 'diamonds', 0, 5),
          ),
          const SizedBox(height: 10),
          _rewardTile(
            icon: Icons.home_work_rounded,
            title: 'Instant rent',
            subtitle: '+\$420 from your studio',
            color: _green,
            claimed: game.claimedRewards.contains('rent'),
            enabled: !game.claimedRewards.contains('rent') &&
                game.properties.isNotEmpty,
            disabledLabel: 'Unavailable',
            onTap: () => _reward(context, game, rewardedAds, 'rent', 420, 0),
          ),
          const SizedBox(height: 20),
          glassCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline_rounded, color: _muted, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                rewardedAds == null
                    ? 'Rewards are simulated in this demo. Production rewards must be granted only after Google Mobile Ads confirms the earned-reward callback.'
                    : 'Cash and diamond rewards are applied only after the ad reports an earned reward. Client-side reward claims are not cheat-resistant.',
                style: const TextStyle(color: _muted, fontSize: 11, height: 1.5),
              ),
            ),
          ])),
        ],
      );
}

Widget _balanceColumn(String title, String value, Color color, IconData icon) => Column(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 8),
      Text(title, style: const TextStyle(color: _muted, fontSize: 9, letterSpacing: 1)),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
    ]);

Widget _rewardTile({
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
          OutlinedButton(onPressed: onTap, style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color.withValues(alpha: .5))), child: const Text('Watch')),
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
  var earned = true;
  if (id != 'rent' && rewardedAds != null) {
    try {
      earned = await rewardedAds.showRewardedAd();
    } catch (error) {
      if (context.mounted) _showMessage(context, 'Could not load or show ad: $error');
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
        ? 'Watch the full ad to earn this reward.'
        : claimed
            ? 'Reward claimed.'
            : 'Daily reward limit reached.',
  );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.game, this.authService, super.key});
  final GameState game;
  final AuthService? authService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool sound = true;
  bool haptics = true;
  String language = 'English';
  late final Stream<UserAccount?>? accountStream;

  @override
  void initState() {
    super.initState();
    accountStream = widget.authService?.watchCurrentUser();
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
                    account?.displayName ?? 'Empire Builder',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    account?.email ??
                        (widget.authService == null
                            ? 'Demo profile · local only'
                            : 'Sign in to sync your Google profile'),
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(child: _stat('NET WORTH', money(widget.game.netWorth), _gold)),
                    Expanded(
                      child: _stat(
                        'PROPERTIES',
                        '${widget.game.properties.length}',
                        _cyan,
                      ),
                    ),
                    Expanded(child: _stat('ITEMS', '${widget.game.inventory.length}', _green)),
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
                    title: Text(account?.displayName ?? 'Connect Google account'),
                    subtitle: Text(
                      snapshot.hasError
                          ? 'Could not load account: ${snapshot.error}'
                          : account?.email ?? 'Sync a profile with Firebase',
                    ),
                    trailing: TextButton(
                      onPressed: snapshot.connectionState == ConnectionState.waiting
                          ? null
                          : () => _toggleAccount(context, widget.authService!, account),
                      child: Text(account == null ? 'Sign in' : 'Sign out'),
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 18),
          sectionTitle('Preferences'),
          glassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(children: [
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Sound effects'), secondary: const Icon(Icons.volume_up_rounded, color: _muted), value: sound, onChanged: (value) => setState(() => sound = value)),
              const Divider(height: 1, color: Color(0xFF2A3040)),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Haptic feedback'), secondary: const Icon(Icons.vibration_rounded, color: _muted), value: haptics, onChanged: (value) => setState(() => haptics = value)),
              const Divider(height: 1, color: Color(0xFF2A3040)),
              ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.translate_rounded, color: _muted), title: const Text('Language'), trailing: DropdownButton<String>(value: language, underline: const SizedBox.shrink(), items: const [DropdownMenuItem(value: 'English', child: Text('English')), DropdownMenuItem(value: 'עברית', child: Text('עברית'))], onChanged: (value) => setState(() => language = value!))),
            ]),
          ),
          const SizedBox(height: 12),
          glassCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.school_rounded, color: _gold),
              title: const Text('How to play'),
              subtitle: const Text('Learn to furnish and trade'),
              trailing: const Icon(Icons.chevron_right_rounded, color: _muted),
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Build your empire'),
                  content: const Text('1. Place an item in your studio to build prestige.\n\n2. List spare items at the Auction House or quick-sell them for cash.\n\n3. Bid on assets, collect rent, and grow your net worth.'),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Let’s go'))],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(child: Text('AUCTION EMPIRE · DEMO BUILD', style: TextStyle(color: _muted, fontSize: 9, letterSpacing: 1.4))),
        ],
      );
}

Future<void> _toggleAccount(
  BuildContext context,
  AuthService authService,
  UserAccount? account,
) async {
  try {
    if (account == null) {
      await authService.signInWithGoogle();
    } else {
      await authService.signOut();
    }
  } catch (error) {
    if (context.mounted) _showMessage(context, 'Account action failed: $error');
  }
}

Widget _stat(String label, String value, Color color) => Column(children: [
      Text(label, style: const TextStyle(color: _muted, fontSize: 8, letterSpacing: .7)),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14, fontFeatures: const [FontFeature.tabularFigures()])),
    ]);

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
}
