import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/game_artwork.dart';
import '../../../game_state.dart';
import '../../../l10n/app_localization_helpers.dart';
import '../../../l10n/generated/app_localizations.dart';

enum _MapLevel { regions, city, street, interior }

class InteractiveWorldMap extends StatefulWidget {
  const InteractiveWorldMap({
    required this.game,
    required this.onManageHome,
    super.key,
  });

  final GameState game;
  final VoidCallback onManageHome;

  @override
  State<InteractiveWorldMap> createState() => _InteractiveWorldMapState();
}

class _InteractiveWorldMapState extends State<InteractiveWorldMap> {
  static const _regions = [
    ('Northbank', Icons.park_rounded, Color(0xFF315D4A)),
    ('Crown Heights', Icons.location_city_rounded, Color(0xFF46566C)),
    ('Old Quarter', Icons.storefront_rounded, Color(0xFF72513E)),
    ('Azure Marina', Icons.sailing_rounded, Color(0xFF315C70)),
  ];

  static const _cityBlocks = [
    ('Aurelia City', Icons.location_city_rounded, Color(0xFF46566C)),
    ('Westhaven City', Icons.park_rounded, Color(0xFF315D4A)),
    ('Old Port City', Icons.storefront_rounded, Color(0xFF72513E)),
    ('Azure City', Icons.sailing_rounded, Color(0xFF315C70)),
  ];

  static const _streetName = 'Willow Lane';

  static const _streetSites = [
    _MapSite(
      id: 'my-home',
      title: 'Starter home',
      owner: 'You',
      icon: Icons.home_work_rounded,
      color: AppColors.primaryGold,
      x: 82,
      y: 82,
      hasInterior: true,
      hasAccess: true,
      isHome: true,
    ),
    _MapSite(
      id: 'luna-lofts',
      title: 'Luna Lofts',
      owner: 'Mira Chen',
      icon: Icons.apartment_rounded,
      color: Color(0xFF9B8CFF),
      x: 260,
      y: 72,
      hasInterior: true,
      hasAccess: true,
    ),
    _MapSite(
      id: 'central-park',
      title: 'Central Park',
      owner: 'Northbank Conservancy',
      icon: Icons.park_rounded,
      color: Color(0xFF73D89A),
      x: 455,
      y: 80,
      hasInterior: false,
      hasAccess: true,
    ),
    _MapSite(
      id: 'corner-market',
      title: 'The Corner Market',
      owner: 'Ari Levin',
      icon: Icons.storefront_rounded,
      color: Color(0xFFFFB36B),
      x: 610,
      y: 82,
      hasInterior: true,
      hasAccess: false,
    ),
    _MapSite(
      id: 'gallery-house',
      title: 'Gallery House',
      owner: 'Jonas Pike',
      icon: Icons.palette_rounded,
      color: Color(0xFFFF8AA0),
      x: 92,
      y: 278,
      hasInterior: true,
      hasAccess: false,
    ),
    _MapSite(
      id: 'willow-villa',
      title: 'Willow Villa',
      owner: 'Celeste King',
      icon: Icons.villa_rounded,
      color: Color(0xFFFFD18B),
      x: 285,
      y: 278,
      hasInterior: true,
      hasAccess: false,
    ),
    _MapSite(
      id: 'civic-offices',
      title: 'Civic Offices',
      owner: 'Apex Holdings',
      icon: Icons.business_rounded,
      color: Color(0xFF76D7E8),
      x: 486,
      y: 278,
      hasInterior: true,
      hasAccess: false,
    ),
    _MapSite(
      id: 'sculpture-garden',
      title: 'Sculpture Garden',
      owner: 'Northbank Conservancy',
      icon: Icons.nature_people_rounded,
      color: Color(0xFF73D89A),
      x: 635,
      y: 278,
      hasInterior: false,
      hasAccess: true,
    ),
  ];

  final TransformationController _transform = TransformationController();
  _MapLevel _level = _MapLevel.regions;
  _MapSite? _selectedSite;
  String? _region;
  String? _city;
  bool _accessRequested = false;

  @override
  void initState() {
    super.initState();
    _transform.value = Matrix4.identity()..scale(.53);
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _enterRegion(String region) {
    setState(() {
      _region = region;
      _city = null;
      _selectedSite = null;
      _level = _MapLevel.city;
    });
  }

  void _enterCity(String city) {
    setState(() {
      _city = city;
      _selectedSite = null;
      _level = _MapLevel.street;
    });
  }

  void _goTo(_MapLevel level) {
    setState(() {
      _level = level;
      if (level.index < _MapLevel.street.index) {
        _selectedSite = null;
        _city = null;
      }
      if (level == _MapLevel.regions) _region = null;
      _accessRequested = false;
    });
  }

  void _zoom(double factor) {
    final currentScale = _transform.value.getMaxScaleOnAxis();
    final nextScale = (currentScale * factor).clamp(.4, 2.8).toDouble();
    _transform.value = Matrix4.identity()..scale(nextScale);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBreadcrumbs(),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 330,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF172321), Color(0xFF171D29)],
                ),
              ),
              child: Stack(
                children: [
                  InteractiveViewer(
                    transformationController: _transform,
                    alignment: Alignment.center,
                    minScale: .4,
                    maxScale: 2.8,
                    boundaryMargin: const EdgeInsets.all(90),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: .97, end: 1).animate(animation),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_level),
                        child: _buildMapCanvas(),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _mapBadge(
                      icon: Icons.public_rounded,
                      label: _levelLabel,
                      color: AppColors.diamondCyan,
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Column(
                      children: [
                        _zoomButton(Icons.add_rounded, l10n.mapZoomIn, () => _zoom(1.25)),
                        const SizedBox(height: 6),
                        _zoomButton(
                          Icons.remove_rounded,
                          l10n.mapZoomOut,
                          () => _zoom(.8),
                        ),
                        const SizedBox(height: 6),
                        _zoomButton(
                          Icons.my_location_rounded,
                          l10n.mapReset,
                          () => _transform.value = Matrix4.identity()..scale(.53),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: _mapBadge(
                      icon: Icons.touch_app_rounded,
                      label: l10n.mapExploreHint,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_level == _MapLevel.street && _selectedSite != null)
            _buildSiteCard(_selectedSite!)
          else if (_level == _MapLevel.interior)
            _buildInterior()
          else
            _buildMapHint(),
        ],
      );
  }

  String get _levelLabel {
    final l10n = AppLocalizations.of(context)!;
    return switch (_level) {
        _MapLevel.regions => l10n.mapSharedWorld,
        _MapLevel.city => (_region ?? 'NORTHBANK').toUpperCase(),
        _MapLevel.street => _streetName.toUpperCase(),
        _MapLevel.interior => l10n.mapPropertyInterior,
      };
  }

  Widget _buildBreadcrumbs() {
    final l10n = AppLocalizations.of(context)!;
    final crumbs = <(String, _MapLevel)>[
      (l10n.pageWorld, _MapLevel.regions),
      if (_region != null) (_region!, _MapLevel.city),
      if (_city != null) (_city!, _MapLevel.street),
      if (_level == _MapLevel.interior)
        (
          _selectedSite == null ? l10n.mapHome : _siteTitle(_selectedSite!),
          _MapLevel.interior,
        ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < crumbs.length; index++) ...[
            if (index > 0)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 5),
                child: Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            TextButton(
              onPressed: crumbs[index].$2 == _level
                  ? null
                  : () => _goTo(crumbs[index].$2),
              style: TextButton.styleFrom(
                foregroundColor: crumbs[index].$2 == _level
                    ? AppColors.primaryGold
                    : AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                crumbs[index].$1,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMapCanvas() {
    final l10n = AppLocalizations.of(context)!;
    if (_level == _MapLevel.interior) {
      return _buildRoomCanvas();
    }

    return SizedBox(
      width: 700,
      height: 440,
      child: CustomPaint(
        painter: _CityMapPainter(level: _level),
        child: Stack(
          children: [
            if (_level == _MapLevel.regions)
              ..._regionMarkers()
            else if (_level == _MapLevel.city)
              ..._cityMarkers()
            else ...[
              Positioned(
                left: 286,
                top: 182,
                child: _streetSign(_streetName, l10n.mapPlayerAddresses),
              ),
              ..._streetMarkers(),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _regionMarkers() {
    final l10n = AppLocalizations.of(context)!;
    const positions = [
      (30.0, 40.0),
      (375.0, 34.0),
      (64.0, 245.0),
      (390.0, 248.0),
    ];
    return [
      for (var i = 0; i < _regions.length; i++)
        Positioned(
          left: positions[i].$1,
          top: positions[i].$2,
          child: _mapAreaCard(
            title: _regions[i].$1,
            subtitle: l10n.mapDistrictCount(5 + i * 2),
            icon: _regions[i].$2,
            color: _regions[i].$3,
            onTap: () => _enterRegion(_regions[i].$1),
          ),
        ),
    ];
  }

  List<Widget> _cityMarkers() {
    final l10n = AppLocalizations.of(context)!;
    const positions = [
      (28.0, 38.0),
      (375.0, 38.0),
      (30.0, 245.0),
      (378.0, 245.0),
    ];
    return [
      Positioned(
        left: 285,
        top: 178,
        child: _streetSign(_region ?? 'Northbank', l10n.mapCityCenter),
      ),
      for (var i = 0; i < _cityBlocks.length; i++)
        Positioned(
          left: positions[i].$1,
          top: positions[i].$2,
          child: _mapAreaCard(
            title: _cityBlocks[i].$1,
            subtitle: l10n.mapPropertiesCount(8 + i * 3),
            icon: _cityBlocks[i].$2,
            color: _cityBlocks[i].$3,
            onTap: () => _enterCity(_cityBlocks[i].$1),
          ),
        ),
    ];
  }

  List<Widget> _streetMarkers() => [
        for (final site in _streetSites)
          Positioned(
            left: site.x,
            top: site.y,
            child: _siteMarker(site),
          ),
      ];

  Widget _mapAreaCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 238,
            height: 150,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: .93), color.withValues(alpha: .55)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: .2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 25),
                    const Spacer(),
                    const Icon(
                      Icons.north_east_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _streetSign(String name, String subtitle) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xEE101620),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
        ),
        child: Column(
          children: [
            Text(
              name.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.diamondCyan,
                fontSize: 8,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      );

  Widget _siteMarker(_MapSite site) {
    final selected = _selectedSite?.id == site.id;
    final title = _siteTitle(site);
    final l10n = AppLocalizations.of(context)!;
    final owner = site.owner == 'You' ? l10n.mapOwnerYou : site.owner;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedSite = site;
        _accessRequested = false;
      }),
      child: Semantics(
        button: true,
        label: l10n.mapSiteSemantics(title, owner),
        child: SizedBox(
          width: 85,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: selected ? 65 : 56,
                height: selected ? 65 : 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      site.color.withValues(alpha: selected ? .4 : .25),
                      const Color(0xFF171D29),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: selected || site.isHome ? site.color : Colors.white24,
                    width: selected || site.isHome ? 1.7 : 1,
                  ),
                  boxShadow: selected || site.isHome
                      ? [
                          BoxShadow(
                            color: site.color.withValues(alpha: .23),
                            blurRadius: 18,
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(site.icon, color: site.color, size: 29),
                    if (site.isHome)
                      const Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(
                          Icons.star_rounded,
                          color: AppColors.primaryGold,
                          size: 14,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xE910141C),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: site.isHome ? AppColors.primaryGold : Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSiteCard(_MapSite site) {
    final l10n = AppLocalizations.of(context)!;
    final name = _siteTitle(site);
    final owner = site.owner == 'You' ? l10n.mapOwnerYou : site.owner;
    final canEnter = site.hasInterior && (site.hasAccess || site.isHome);
    final buttonLabel = !site.hasInterior
        ? l10n.mapExploreLandmark
        : canEnter
            ? l10n.mapEnterProperty
            : _accessRequested
                ? l10n.mapAccessRequested
                : l10n.mapRequestAccess;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.borderGlass),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: site.color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(site.icon, color: site.color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(
                      l10n.mapOwnedBy(owner),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(
                site.isHome ? Icons.verified_rounded : Icons.place_rounded,
                color: site.isHome ? AppColors.accentGreen : AppColors.textSecondary,
                size: 19,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  site.hasInterior
                      ? site.hasAccess || site.isHome
                          ? l10n.mapInteriorAvailable
                          : _accessRequested
                              ? l10n.mapWaitingForOwner
                              : l10n.mapOwnerControlsAccess
                      : l10n.mapPublicLandmark,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ),
              if (!site.hasInterior)
                OutlinedButton.icon(
                  onPressed: () => _showLandmarkDetails(site),
                  icon: const Icon(Icons.info_outline_rounded, size: 16),
                  label: Text(buttonLabel),
                )
              else if (canEnter)
                FilledButton.icon(
                  onPressed: () => setState(() => _level = _MapLevel.interior),
                  icon: const Icon(Icons.door_front_door_rounded, size: 16),
                  label: Text(buttonLabel),
                )
              else
                OutlinedButton.icon(
                  onPressed: _accessRequested
                      ? null
                      : () => setState(() => _accessRequested = true),
                  icon: Icon(
                    _accessRequested
                        ? Icons.hourglass_top_rounded
                        : Icons.lock_open_rounded,
                    size: 16,
                  ),
                  label: Text(buttonLabel),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLandmarkDetails(_MapSite site) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(site.icon, color: site.color, size: 30),
              const SizedBox(height: 10),
              Text(_siteTitle(site), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(
                l10n.mapSharedPlace(site.owner),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInterior() {
    final l10n = AppLocalizations.of(context)!;
    final site = _selectedSite!;
    final isHome = site.isHome;
    final title = _siteTitle(site);
    final placedItems = isHome
        ? widget.game.inventory.where((item) => item.placed).toList()
        : <GameItem>[];
    final hostItems = isHome
        ? <(String, IconData, Color)>[]
        : const [
            ('Sculpture', Icons.museum_outlined, Color(0xFFFFD18B)),
            ('Lounge sofa', Icons.weekend_rounded, Color(0xFF9B8CFF)),
          ];
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.borderGlass),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.home_rounded, color: AppColors.primaryGold, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.roomTitle(
                    title,
                    isHome ? l10n.roomHome : l10n.roomGuest,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: () => _goTo(_MapLevel.street),
                icon: const Icon(Icons.map_outlined, size: 16),
                label: Text(l10n.exit),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isHome
                ? l10n.roomHomeDescription
                : l10n.roomGuestDescription,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              for (final item in placedItems)
                _roomAsset(
                  label: localizedItemName(l10n, item.name),
                  icon: item.icon,
                  color: AppColors.primaryGold,
                  onTap: () => _inspectRoomAsset(
                    localizedItemName(l10n, item.name),
                    l10n.roomItemDetails(
                      localizedRarity(l10n, item.rarity),
                      localizedCategory(l10n, item.category),
                      item.value,
                    ),
                  ),
                ),
              for (final item in hostItems)
                _roomAsset(
                  label: item.$1 == 'Sculpture'
                      ? l10n.roomSculpture
                      : l10n.roomLoungeSofa,
                  icon: item.$2,
                  color: item.$3,
                  onTap: () => _inspectRoomAsset(
                    item.$1 == 'Sculpture'
                        ? l10n.roomSculpture
                        : l10n.roomLoungeSofa,
                    l10n.roomOwnerAsset,
                  ),
                ),
              if (placedItems.isEmpty && hostItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    l10n.roomNoItems,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          if (isHome) ...[
            const SizedBox(height: 13),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                onPressed: widget.onManageHome,
                icon: const Icon(Icons.grid_view_rounded, size: 17),
                label: Text(l10n.roomManage),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _roomAsset({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: 104,
          height: 88,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: color.withValues(alpha: .35)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 27),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );

  void _inspectRoomAsset(String name, String details) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name),
        content: Text(details),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCanvas() {
    final site = _selectedSite!;
    return SizedBox(
      width: 700,
      height: 440,
      child: CustomPaint(
        painter: const _RoomPainter(),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IsometricPropertyArt(
                style: site.isHome ? PropertyArtStyle.shed : PropertyArtStyle.villa,
                size: 150,
              ),
              const SizedBox(height: 9),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xE910141C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  _siteTitle(site).toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primaryGold,
                    letterSpacing: 1.5,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _siteTitle(_MapSite site) {
    final l10n = AppLocalizations.of(context)!;
    if (site.isHome && widget.game.properties.isNotEmpty) {
      return localizedPropertyName(l10n, widget.game.properties.first.name);
    }
    return switch (site.id) {
      'my-home' => l10n.mapStarterHome,
      'corner-market' => l10n.mapCornerMarket,
      'gallery-house' => l10n.mapGalleryHouse,
      'willow-villa' => l10n.mapWillowVilla,
      'civic-offices' => l10n.mapCivicOffices,
      'sculpture-garden' => l10n.mapSculptureGarden,
      _ => site.title,
    };
  }

  Widget _buildMapHint() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Row(
          children: [
            const Icon(Icons.explore_rounded, color: AppColors.diamondCyan, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                switch (_level) {
                  _MapLevel.regions => l10n.mapChooseRegionHint,
                  _MapLevel.city => l10n.mapChooseCityHint,
                  _MapLevel.street => l10n.mapSelectBuildingHint,
                  _MapLevel.interior => '',
                },
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
            if (_level == _MapLevel.street)
              const Icon(Icons.touch_app_rounded, color: AppColors.primaryGold, size: 19),
          ],
        ),
      );
  }

  Widget _mapBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xE910141C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: .1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 8,
                letterSpacing: .7,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );

  Widget _zoomButton(IconData icon, String tooltip, VoidCallback onPressed) =>
      Tooltip(
        message: tooltip,
        child: Material(
          color: const Color(0xE910141C),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(icon, color: Colors.white, size: 18),
            ),
          ),
        ),
      );
}

class _MapSite {
  const _MapSite({
    required this.id,
    required this.title,
    required this.owner,
    required this.icon,
    required this.color,
    required this.x,
    required this.y,
    required this.hasInterior,
    required this.hasAccess,
    this.isHome = false,
  });

  final String id;
  final String title;
  final String owner;
  final IconData icon;
  final Color color;
  final double x;
  final double y;
  final bool hasInterior;
  final bool hasAccess;
  final bool isHome;
}

class _CityMapPainter extends CustomPainter {
  const _CityMapPainter({required this.level});

  final _MapLevel level;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = const Color(0xFF1C2928));

    final blockPaint = Paint()..color = const Color(0xFF263532);
    for (var row = 0; row < 3; row++) {
      for (var column = 0; column < 4; column++) {
        final rect = Rect.fromLTWH(
          18.0 + column * 172.0,
          18.0 + row * 142.0,
          150,
          112,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(16)),
          blockPaint,
        );
      }
    }

    final road = Paint()
      ..color = const Color(0xFF394344)
      ..strokeWidth = level == _MapLevel.street ? 38 : 28
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, 220), Offset(size.width, 220), road);
    canvas.drawLine(const Offset(350, 0), Offset(350, size.height), road);

    final lane = Paint()
      ..color = const Color(0xFFB7A878).withValues(alpha: .35)
      ..strokeWidth = 1.2;
    for (var x = 10.0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 220), Offset(x + 11, 220), lane);
    }
    for (var y = 8.0; y < size.height; y += 24) {
      canvas.drawLine(Offset(350, y), Offset(350, y + 11), lane);
    }

    final park = Paint()..color = const Color(0xFF315541);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(388, 46, 118, 102),
        const Radius.circular(22),
      ),
      park,
    );
    final tree = Paint()..color = const Color(0xFF70A77E);
    for (final point in [
      const Offset(411, 68),
      const Offset(456, 77),
      const Offset(432, 119),
      const Offset(481, 119),
    ]) {
      canvas.drawCircle(point, 8, tree);
      canvas.drawCircle(
        point.translate(-2, -3),
        3,
        Paint()..color = const Color(0xFFA8D68E),
      );
    }

    if (level == _MapLevel.street) {
      final plotLine = Paint()
        ..color = Colors.white.withValues(alpha: .13)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      for (final rect in [
        const Rect.fromLTWH(25, 35, 155, 150),
        const Rect.fromLTWH(203, 35, 155, 150),
        const Rect.fromLTWH(380, 35, 155, 150),
        const Rect.fromLTWH(548, 35, 125, 150),
        const Rect.fromLTWH(25, 254, 155, 150),
        const Rect.fromLTWH(203, 254, 155, 150),
        const Rect.fromLTWH(380, 254, 155, 150),
        const Rect.fromLTWH(548, 254, 125, 150),
      ]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(13)),
          plotLine,
        );
      }
    }

    final glow = Paint()
      ..color = AppColors.diamondCyan.withValues(alpha: .08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawCircle(const Offset(610, 375), 88, glow);
  }

  @override
  bool shouldRepaint(_CityMapPainter oldDelegate) =>
      level != oldDelegate.level;
}

class _RoomPainter extends CustomPainter {
  const _RoomPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final floor = Paint()..color = const Color(0xFF6D594A);
    final tile = Paint()..color = const Color(0xFF786252);
    canvas.drawRect(Offset.zero & size, floor);
    for (var row = 0; row < 8; row++) {
      for (var column = 0; column < 12; column++) {
        if ((row + column).isEven) {
          canvas.drawRect(
            Rect.fromLTWH(column * 60.0, row * 56.0, 60, 56),
            tile..color = const Color(0xFF786252).withValues(alpha: .5),
          );
        }
      }
    }
    final wall = Paint()..color = const Color(0xFFD1B992);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 700, 28), wall);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 22, 440), wall);
    canvas.drawRect(const Rect.fromLTWH(678, 0, 22, 440), wall);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(185, 90, 330, 260),
        const Radius.circular(42),
      ),
      Paint()..color = const Color(0xFFAF8A67),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(205, 110, 290, 220),
        const Radius.circular(36),
      ),
      Paint()..color = const Color(0xFF4A3A36),
    );
  }

  @override
  bool shouldRepaint(_RoomPainter oldDelegate) => false;
}
