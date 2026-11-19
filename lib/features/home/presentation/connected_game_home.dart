import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../app/assets/app_assets.dart';
import '../../../app/providers/app_services.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/app_icon.dart';
import '../../../app/widgets/game_artwork.dart';
import '../../../core/models/asset_item.dart';
import '../../../core/models/auction.dart';
import '../../../core/models/property.dart';
import '../../../core/models/user_account.dart';

/// Read-only player workspace backed exclusively by the injected live services.
class ConnectedGameHome extends StatefulWidget {
  const ConnectedGameHome({
    required this.services,
    required this.onLocaleChanged,
    super.key,
  });

  final AppServices services;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<ConnectedGameHome> createState() => _ConnectedGameHomeState();
}

class _ConnectedGameHomeState extends State<ConnectedGameHome> {
  int _destination = 0;
  StreamSubscription<UserAccount?>? _accountSub;
  StreamSubscription<List<Property>>? _propertySub;
  StreamSubscription<List<AssetItem>>? _assetSub;
  StreamSubscription<List<Auction>>? _auctionSub;
  UserAccount? _account;
  List<Property>? _properties;
  List<AssetItem>? _assets;
  List<Auction>? _auctions;
  Object? _accountError, _propertyError, _assetError, _auctionError;

  @override
  void initState() {
    super.initState();
    _accountSub = widget.services.auth.watchCurrentUser().listen((account) {
      if (!mounted) return;
      setState(() {
        _account = account;
        _properties = null;
        _assets = null;
        _accountError = null;
      });
      _propertySub?.cancel();
      _assetSub?.cancel();
      if (account != null) {
        _propertySub = widget.services.properties
            .watchByOwner(account.uid)
            .listen(
              (rows) => _update(() => _properties = rows),
              onError: (Object error) => _update(() => _propertyError = error),
            );
        _assetSub = widget.services.assets.watchByOwner(account.uid).listen(
              (rows) => _update(() => _assets = rows),
              onError: (Object error) => _update(() => _assetError = error),
            );
      }
    }, onError: (Object error) => _update(() => _accountError = error));
    _auctionSub = widget.services.auctions.watchActive().listen(
          (rows) => _update(() => _auctions = rows),
          onError: (Object error) => _update(() => _auctionError = error),
        );
  }

  void _update(VoidCallback change) {
    if (mounted) setState(change);
  }

  @override
  void dispose() {
    _accountSub?.cancel();
    _propertySub?.cancel();
    _assetSub?.cancel();
    _auctionSub?.cancel();
    super.dispose();
  }

  List<String> _primaryLabels(AppLocalizations l10n) => [
        l10n.navMap,
        l10n.navAuctions,
        l10n.navAssets,
        l10n.navBank,
        l10n.navProfile,
      ];
  static const _icons = [
    Icons.map_outlined,
    Icons.gavel_rounded,
    Icons.inventory_2_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.person_outline,
    Icons.settings_outlined
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 820;
            return Row(children: [
              if (wide) _navigation(rail: true),
              Expanded(
                  child: Column(children: [
                _header(wide: wide),
                Expanded(child: _destinationView()),
                if (!wide) _navigation(rail: false),
              ])),
            ]);
          }),
        ),
      );

  Widget _header({required bool wide}) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.outline))),
        child: Row(children: [
          const Icon(Icons.diamond_outlined, color: AppColors.primaryGold),
          const SizedBox(width: 10),
          Expanded(
              child: Text(l10n.workspaceTitle,
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700))),
          if (_account != null)
            Text(_account!.displayName,
                style: const TextStyle(color: AppColors.textSecondary)),
          if (!wide)
            IconButton(
                tooltip: l10n.settings,
                onPressed: () => setState(() => _destination = 5),
                icon: const Icon(Icons.settings_outlined,
                    color: AppColors.textSecondary)),
        ]),
      );
  }

  Widget _navigation({required bool rail}) {
    final l10n = AppLocalizations.of(context)!;
    final labels = _primaryLabels(l10n);
    if (rail) {
      return NavigationRail(
        backgroundColor: AppColors.surface,
        selectedIndex: _destination,
        onDestinationSelected: (value) => setState(() => _destination = value),
        labelType: NavigationRailLabelType.all,
        destinations: List.generate(
            6,
            (i) => NavigationRailDestination(
                icon: Icon(_icons[i]),
                label: Text(i == 5 ? l10n.settings : labels[i]))),
      );
    }
    return NavigationBar(
      backgroundColor: AppColors.surface,
      selectedIndex: _destination.clamp(0, 4),
      onDestinationSelected: (value) => setState(() => _destination = value),
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      destinations: List.generate(
          5,
          (i) => NavigationDestination(icon: Icon(_icons[i]), label: labels[i])),
    );
  }

  Widget _destinationView() => switch (_destination) {
        0 => _mapPage(),
        1 => _auctionPage(),
        2 => _inventoryPage(),
        3 => _bankPage(),
        4 => _profilePage(),
        _ => _settingsPage(),
      };

  Widget _page(String title, String subtitle, Widget child) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 5),
          Text(subtitle,
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 18),
          Expanded(child: child),
        ]),
      );

  Widget _mapPage() {
    final l10n = AppLocalizations.of(context)!;
    return _page(
      l10n.propertyMap,
      l10n.propertyMapSubtitle,
      _streamState(_properties, _propertyError, (rows) {
        final located = rows
            .where((p) => p.coordinates.lat != null || p.coordinates.x != null)
            .toList();
        final missing = rows.length - located.length;
        return Column(children: [
          Expanded(child: _PropertyMap(properties: located)),
          if (missing > 0)
            _notice(
                l10n.missingCoordinates(missing)),
          if (rows.isEmpty) _notice(l10n.noOwnedProperties),
        ]);
      }));
  }

  Widget _auctionPage() {
    final l10n = AppLocalizations.of(context)!;
    return _page(
      l10n.activeAuctions,
      l10n.auctionsSubtitle,
      _streamState(
          _auctions,
          _auctionError,
          (rows) => rows.isEmpty
              ? _empty(l10n.noAuctions)
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) => _auctionCard(rows[i]))));
  }

  Widget _auctionCard(Auction auction) {
    final l10n = AppLocalizations.of(context)!;
    return
      _card(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GameItemArtwork(
            icon: Icons.inventory_2_outlined,
            itemName: auction.itemId,
            category: l10n.realEstate,
            size: 58,
            semanticLabel: l10n.auctionItemSemantics),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.auctionLabel(auction.id),
              style: const TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(l10n.itemReference(auction.itemId),
              style: const TextStyle(color: AppColors.textSecondary)),
          Text(
              l10n.auctionTypeState(auction.auctionType.name, auction.status.name),
              style: const TextStyle(color: AppColors.textSecondary)),
          Text(
              l10n.auctionPrices(_money(auction.startingPrice), _money(auction.currentHighestBid)),
              style: const TextStyle(color: AppColors.primaryGold)),
          Text(l10n.auctionEnds(auction.endTime.toLocal().toString()),
              style: const TextStyle(color: AppColors.textSecondary)),
        ])),
      ]));
  }

  Widget _inventoryPage() {
    final l10n = AppLocalizations.of(context)!;
    return _page(
      l10n.inventory,
      l10n.inventorySubtitle,
      _streamState(
          _assets,
          _assetError,
          (rows) => rows.isEmpty
              ? _empty(l10n.noAssets)
              : LayoutBuilder(
                  builder: (context, c) => GridView.builder(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 350,
                          mainAxisExtent: 160,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12),
                      itemCount: rows.length,
                      itemBuilder: (context, i) => _assetCard(rows[i])))));
  }

  Widget _assetCard(AssetItem item) => _card(Row(children: [
        GameItemArtwork(
            icon: Icons.category_outlined,
            itemName: item.name,
            category: switch (item.category) {
              AssetCategory.furniture => 'Furniture',
              AssetCategory.vehicle => 'Vehicles',
              AssetCategory.boat => 'Boats',
              _ => null
            },
            size: 62,
            semanticLabel: item.name),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              Text(item.name,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700)),
              Text(
              '${item.category.name} · ${item.rarity.name}',
                  style: const TextStyle(color: AppColors.textSecondary)),
              Text(AppLocalizations.of(context)!.estimated(_money(item.estimatedValue)),
                  style: const TextStyle(color: AppColors.primaryGold)),
              Text(AppLocalizations.of(context)!.assetId(item.id),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
            ])),
      ]));

  Widget _bankPage() {
    final l10n = AppLocalizations.of(context)!;
    return _page(
      l10n.bankRewards,
      l10n.bankSubtitle,
      _streamState<UserAccount>(
          _account == null ? null : _account,
          _accountError,
          (account) => ListView(children: [
                _balanceTile('Available cash', AppAssets.cash,
                    _money(account.cashBalance - account.reservedBalance)),
                _balanceTile(l10n.reservedCash, AppAssets.cash,
                    _money(account.reservedBalance)),
                _balanceTile('Gems', AppAssets.gem, '${account.gems}'),
                _balanceTile(l10n.netWorth, AppAssets.realEstate,
                    _money(account.netWorth)),
                _card(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.rewards,
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700)),
                      SizedBox(height: 6),
                      Text(l10n.rewardsReadOnly,
                          style: TextStyle(color: AppColors.textSecondary)),
                      SizedBox(height: 12),
                      OutlinedButton(
                          onPressed: null, child: Text(l10n.claimRewards))
                    ])),
                _notice(
                    l10n.economyReadOnly),
              ])));
  }

  Widget _balanceTile(String title, String icon, String value) =>
      _card(Row(children: [
        AppIcon(assetName: icon, color: AppColors.primaryGold),
        const SizedBox(width: 12),
        Expanded(
            child: Text(title,
                style: const TextStyle(color: AppColors.textSecondary))),
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700))
      ]));

  Widget _profilePage() {
    final l10n = AppLocalizations.of(context)!;
    return _page(
      l10n.profile,
      l10n.profileSubtitle,
      _streamState<UserAccount>(
          _account == null ? null : _account,
          _accountError,
          (account) => ListView(children: [
                _card(Row(children: [
                  CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.surfaceRaised,
                      backgroundImage: account.photoUrl.isEmpty
                          ? null
                          : NetworkImage(account.photoUrl),
                      child: account.photoUrl.isEmpty
                          ? const Icon(Icons.person_outline,
                              color: AppColors.primaryGold)
                          : null),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(account.displayName,
                            style: const TextStyle(
                                fontSize: 20,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700)),
                        Text(account.email,
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                        Text(l10n.accountId(account.uid),
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12))
                      ]))
                ])),
                _balanceTile(l10n.memberSince, AppAssets.profile,
                    account.createdAt.toLocal().toString().split(' ').first),
              ])));
  }

  Widget _settingsPage() {
    final l10n = AppLocalizations.of(context)!;
    return _page(
      l10n.settings,
      l10n.settingsSubtitle,
      Align(
          alignment: Alignment.topLeft,
          child: _card(
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.language,
                style: TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(spacing: 10, children: [
              OutlinedButton(
                  onPressed: () => widget.onLocaleChanged(const Locale('en')),
                  child: Text(l10n.english)),
              OutlinedButton(
                  onPressed: () => widget.onLocaleChanged(const Locale('he')),
                  child: Text(l10n.hebrew)),
            ])
          ]))));
  }

  Widget _streamState<T>(
      T? value, Object? error, Widget Function(T value) builder) {
    final l10n = AppLocalizations.of(context)!;
    if (error != null)
      return _empty(l10n.liveLoadError('$error'),
          icon: Icons.error_outline);
    if (value == null) return _empty(l10n.loadingRecords, loading: true);
    return builder(value);
  }

  Widget _empty(String text,
          {IconData icon = Icons.inbox_outlined, bool loading = false}) =>
      Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (loading)
          const CircularProgressIndicator(color: AppColors.primaryGold)
        else
          Icon(icon, color: AppColors.textSecondary, size: 32),
        const SizedBox(height: 12),
        Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary))
      ]));
  Widget _notice(String text) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(12)),
      child:
          Text(text, style: const TextStyle(color: AppColors.textSecondary)));
  Widget _card(Widget child) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline)),
      child: child);
  String _money(double amount) => '\$${amount.toStringAsFixed(2)}';
}

class _PropertyMap extends StatefulWidget {
  const _PropertyMap({required this.properties});
  final List<Property> properties;
  @override
  State<_PropertyMap> createState() => _PropertyMapState();
}

class _PropertyMapState extends State<_PropertyMap> {
  final TransformationController _transform = TransformationController();
  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final m = _transform.value.clone()..scale(factor);
    _transform.value = m;
  }

  void _reset() => _transform.value = Matrix4.identity();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, c) => Stack(children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: InteractiveViewer(
                    transformationController: _transform,
                    minScale: .45,
                    maxScale: 4,
                    boundaryMargin: const EdgeInsets.all(300),
                    child: SizedBox(
                        width: c.maxWidth,
                        height: c.maxHeight,
                        child: CustomPaint(
                            painter: _MapGridPainter(),
                            child: _mapPins(c.biggest))))),
            Positioned(
                right: 12,
                top: 12,
                child: Column(children: [
                  IconButton.filledTonal(
                      tooltip: AppLocalizations.of(context)!.zoomIn,
                      onPressed: () => _zoom(1.2),
                      icon: const Icon(Icons.add)),
                  IconButton.filledTonal(
                      tooltip: AppLocalizations.of(context)!.zoomOut,
                      onPressed: () => _zoom(1 / 1.2),
                      icon: const Icon(Icons.remove)),
                  IconButton.filledTonal(
                      tooltip: AppLocalizations.of(context)!.resetMap,
                      onPressed: _reset,
                      icon: const Icon(Icons.fit_screen))
                ])),
          ]));

  Widget _mapPins(Size size) {
    if (widget.properties.isEmpty)
      return Center(
          child: Text(AppLocalizations.of(context)!.noLocatedProperties,
              style: const TextStyle(color: AppColors.textSecondary)));
    final geo =
        widget.properties.where((p) => p.coordinates.lat != null).toList();
    final grid =
        widget.properties.where((p) => p.coordinates.x != null).toList();
    final isGeo = geo.isNotEmpty;
    final points = isGeo ? geo : grid;
    final xs = points
        .map((p) => isGeo ? p.coordinates.lng! : p.coordinates.x!.toDouble())
        .toList();
    final ys = points
        .map((p) => isGeo ? p.coordinates.lat! : p.coordinates.y!.toDouble())
        .toList();
    final minX = xs.reduce((a, b) => a < b ? a : b),
        maxX = xs.reduce((a, b) => a > b ? a : b);
    final minY = ys.reduce((a, b) => a < b ? a : b),
        maxY = ys.reduce((a, b) => a > b ? a : b);
    return Stack(children: [
      for (var i = 0; i < points.length; i++)
        Positioned(
            left: 28 +
                (maxX == minX ? .5 : (xs[i] - minX) / (maxX - minX)) *
                    (size.width - 100),
            top: 24 +
                (maxY == minY ? .5 : (ys[i] - minY) / (maxY - minY)) *
                    (size.height - 100),
            child: Tooltip(
                message:
                    '${points[i].name}\n${isGeo ? '${ys[i]}, ${xs[i]}' : AppLocalizations.of(context)!.gridCoordinates(xs[i].toInt(), ys[i].toInt())}',
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  IsometricPropertyArt(style: _art(points[i].type), size: 72),
                  Text(points[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 11))
                ])))
    ]);
  }

  PropertyArtStyle _art(PropertyType type) => switch (type) {
        PropertyType.shed || PropertyType.warehouse => PropertyArtStyle.shed,
        PropertyType.apartment => PropertyArtStyle.apartment,
        PropertyType.marina => PropertyArtStyle.marina,
        _ => PropertyArtStyle.villa
      };
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.surface);
    final minor = Paint()
      ..color = AppColors.outline.withValues(alpha: .45)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 36)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minor);
    for (double y = 0; y < size.height; y += 36)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minor);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
