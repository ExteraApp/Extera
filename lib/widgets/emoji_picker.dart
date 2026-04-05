import 'package:flutter/material.dart';

import 'package:emojis/emoji.dart';

import 'package:extera_next/generated/l10n/l10n.dart';

// ==========================================
// 1. Data Models
// ==========================================

/// Defines the type of emoji content
enum PickerEmojiType { standard, custom }

/// A unified wrapper for both Standard (Unicode) and Custom (Image/Asset) emojis.
class PickerEmoji {
  final PickerEmojiType type;

  // Standard Data
  final Emoji? standardEmoji; // From package

  // Custom Data
  final String? customData; // The Value from the Map (e.g., URL)
  final String? customId; // The Key from the Map (e.g., unique name)
  final String? categoryId; // To link back to CustomCategory.id

  // Common Data for UI/Search
  final String displayName;
  final List<String> keywords;

  PickerEmoji.standard(this.standardEmoji)
    : type = PickerEmojiType.standard,
      customData = null,
      customId = null,
      categoryId = null,
      displayName = standardEmoji!.char,
      keywords = standardEmoji.keywords;

  PickerEmoji.custom({
    required String name,
    required this.customData,
    required this.categoryId,
  }) : type = PickerEmojiType.custom,
       standardEmoji = null,
       customId = name,
       displayName = name,
       keywords = [name]; // Use name as keyword
}

class CustomCategory {
  final String id;
  final String name;
  final Widget icon;

  /// Key: Name/Search term, Value: Data (URL, Path, Identifier)
  final Map<String, String> emojis;

  const CustomCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.emojis,
  });
}

// ==========================================
// 2. Configuration & Callbacks
// ==========================================

/// Updated callback: returns the wrapper so you can handle both types
typedef EmojiSelectionCallback =
    void Function(Category? category, PickerEmoji emoji);

/// Builder for rendering custom emoji tiles
typedef CustomEmojiBuilder =
    Widget Function(BuildContext context, String emojiData, double size);

// Standard Categories
enum Category {
  smileys(Icons.sentiment_satisfied_alt, [
    EmojiGroup.smileysEmotion,
    EmojiGroup.peopleBody,
  ]),
  animals(Icons.pets, [EmojiGroup.animalsNature]),
  food(Icons.fastfood, [EmojiGroup.foodDrink]),
  activities(Icons.sports_soccer, [EmojiGroup.activities]),
  travel(Icons.directions_car, [EmojiGroup.travelPlaces]),
  objects(Icons.lightbulb_outline, [EmojiGroup.objects, EmojiGroup.component]),
  symbols(Icons.emoji_symbols, [EmojiGroup.symbols]),
  flags(Icons.flag, [EmojiGroup.flags]);

  final IconData icon;
  final List<EmojiGroup> groups;

  const Category(this.icon, this.groups);

  static Category fromEmojiGroup(EmojiGroup group) {
    for (final cat in Category.values) {
      if (cat.groups.contains(group)) return cat;
    }
    return Category.symbols;
  }
}

// Internal Tab Abstraction
abstract class _PickerTab {
  Widget get icon;
  String get name;
}

class _StandardTab extends _PickerTab {
  final Category category;
  _StandardTab(this.category);
  @override
  Widget get icon => Icon(category.icon, size: 22);

  @override
  String get name => category.name;
}

class _CustomTab extends _PickerTab {
  final CustomCategory category;
  _CustomTab(this.category);
  @override
  Widget get icon => category.icon;

  @override
  String get name => category.name;
}

class _RecentTab extends _PickerTab {
  _RecentTab();
  @override
  Widget get icon => const Icon(Icons.history, size: 22);

  @override
  String get name => 'Recent';
}

// ==========================================
// 3. Main Widget
// ==========================================

class MatrixEmojiPicker extends StatefulWidget {
  final EmojiSelectionCallback onEmojiSelected;
  final VoidCallback onBackspacePressed;

  /// A list of recent `PickerEmoji` items to show in the "Recent" tab.
  final List<PickerEmoji> recentEmojis;

  final List<CustomCategory> customCategories;

  /// Required to render custom emojis.
  /// [emojiData] is the value from your CustomCategory map.
  final CustomEmojiBuilder? customEmojiBuilder;

  const MatrixEmojiPicker({
    super.key,
    required this.onEmojiSelected,
    required this.onBackspacePressed,
    this.recentEmojis = const [],
    this.customCategories = const [],
    this.customEmojiBuilder,
  });

  @override
  MatrixEmojiPickerState createState() => MatrixEmojiPickerState();
}

class MatrixEmojiPickerState extends State<MatrixEmojiPicker>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  List<PickerEmoji> _allEmojis = [];
  List<PickerEmoji> _displayedEmojis = [];
  final Map<String, List<PickerEmoji>> _variationsMap = {};

  late List<_PickerTab> _tabs;
  late TabController _tabController;
  int _selectedTabIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initTabs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEmojis();
    });
  }

  void _initTabs() {
    _tabs = [
      _RecentTab(),
      ...Category.values.map((c) => _StandardTab(c)),
      ...widget.customCategories.map((c) => _CustomTab(c)),
    ];

    // Reset index if out of bounds (e.g. if categories removed)
    if (_selectedTabIndex >= _tabs.length) {
      _selectedTabIndex = 0;
    }

    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: _selectedTabIndex,
    );
  }

  @override
  void didUpdateWidget(MatrixEmojiPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.customCategories != oldWidget.customCategories ||
        widget.recentEmojis != oldWidget.recentEmojis) {
      _tabController.dispose();
      _initTabs();
      _loadEmojis();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadEmojis() {
    final loadedList = <PickerEmoji>[];
    final tempVariations = <String, List<PickerEmoji>>{};

    // 1. Load Standard
    final rawStandard = Emoji.all();
    for (final emoji in rawStandard) {
      if (emoji.name.contains(':') && emoji.name.contains('skin tone')) {
        final baseName = emoji.name.split(':')[0].trim();
        if (!tempVariations.containsKey(baseName)) {
          tempVariations[baseName] = [];
        }
        tempVariations[baseName]!.add(PickerEmoji.standard(emoji));
      }
    }

    for (final emoji in rawStandard) {
      final pEmoji = PickerEmoji.standard(emoji);
      if (tempVariations.containsKey(emoji.name)) {
        tempVariations[emoji.name]!.insert(0, pEmoji);
      }
      loadedList.add(pEmoji);
    }

    // 2. Load Custom
    for (final cat in widget.customCategories) {
      cat.emojis.forEach((name, data) {
        loadedList.add(
          PickerEmoji.custom(name: name, customData: data, categoryId: cat.id),
        );
      });
    }

    if (mounted) {
      setState(() {
        _allEmojis = loadedList;
        _variationsMap.addAll(tempVariations);
        _isLoading = false;
        _calculateDisplayedEmojis();
      });
    }
  }

  // Pure logic function to filter emojis based on current state
  void _calculateDisplayedEmojis() {
    final searchText = _searchController.text.toLowerCase();
    final currentTab = _tabs[_selectedTabIndex];

    if (searchText.isNotEmpty) {
      // Include recent emojis in search results in addition to the full set
      final source = <PickerEmoji>[];
      source.addAll(_allEmojis);
      for (final r in widget.recentEmojis) {
        if (!source.any(
          (e) => e.displayName == r.displayName && e.type == r.type,
        )) {
          source.add(r);
        }
      }

      _displayedEmojis = source.where((e) {
        if (e.displayName.toLowerCase().contains(searchText)) return true;
        for (final k in e.keywords) {
          if (k.toLowerCase().contains(searchText)) return true;
        }
        return false;
      }).toList();
    } else {
      if (currentTab is _StandardTab) {
        _displayedEmojis = _allEmojis.where((e) {
          if (e.type != PickerEmojiType.standard) return false;
          final matchesCategory = currentTab.category.groups.contains(
            e.standardEmoji!.emojiGroup,
          );
          final isVariation =
              e.displayName.contains(':') &&
              e.displayName.contains('skin tone');
          return matchesCategory && !isVariation;
        }).toList();
      } else if (currentTab is _CustomTab) {
        _displayedEmojis = _allEmojis.where((e) {
          if (e.type != PickerEmojiType.custom) return false;
          return e.categoryId == currentTab.category.id;
        }).toList();
      } else if (currentTab is _RecentTab) {
        _displayedEmojis = widget.recentEmojis.toList();
      }
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _selectedTabIndex = index;
      _searchController.clear(); // Clear search to show category contents
      _calculateDisplayedEmojis();
    });
  }

  void _onSearchChanged() {
    setState(() {
      _calculateDisplayedEmojis();
    });
  }

  // ... _handleEmojiTap and _showSkinToneMenu remain the same ...
  void _handleEmojiTap(PickerEmoji emoji) {
    Category? cat;
    if (emoji.type == PickerEmojiType.standard) {
      cat = Category.fromEmojiGroup(emoji.standardEmoji!.emojiGroup);
    }
    widget.onEmojiSelected(cat, emoji);
  }

  void _showSkinToneMenu(
    BuildContext context,
    PickerEmoji baseEmoji,
    Offset globalPosition,
  ) {
    if (baseEmoji.type != PickerEmojiType.standard) return;
    var lookupName = baseEmoji.standardEmoji!.name;
    if (lookupName.contains(':')) {
      lookupName = lookupName.split(':')[0].trim();
    }
    final variations = _variationsMap[lookupName];
    if (variations == null || variations.isEmpty) return;

    // ... Menu showing logic same as before ...
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(globalPosition - const Offset(0, 50), globalPosition),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Theme.of(context).cardColor,
      items: [
        PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: variations.map((v) {
                return InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    _handleEmojiTap(v);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text(
                      v.displayName,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // --- Search Bar ---
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _onSearchChanged(), // Updated handler
                    decoration: InputDecoration(
                      hintText: L10n.of(context).search,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: widget.onBackspacePressed,
                icon: const Icon(Icons.backspace_outlined),
                color: Colors.grey[700],
              ),
            ],
          ),
        ),

        // --- Category Tab Bar ---
        Container(
          height: 40,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: theme.colorScheme.secondary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: theme.colorScheme.secondary,
            padding: .zero,
            tabAlignment: .start,
            onTap: _onTabTapped,
            tabs: _tabs.map((tab) {
              return Tooltip(
                message: tab.name,
                child: Tab(icon: tab.icon),
              );
            }).toList(),
          ),
        ),

        // --- Grid Area ---
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _displayedEmojis.isEmpty
              ? Center(child: Text(L10n.of(context).nothingFound))
              : CustomScrollView(
                  // Add a Key based on tab index to force scroll position reset on tab switch
                  key: ValueKey(_selectedTabIndex),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(6.0),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 8,
                              mainAxisSpacing: 6,
                              crossAxisSpacing: 6,
                              childAspectRatio: 1.0,
                            ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return _buildEmojiTile(_displayedEmojis[index]);
                        }, childCount: _displayedEmojis.length),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildEmojiTile(PickerEmoji emoji) {
    Widget content;
    if (emoji.type == PickerEmojiType.custom) {
      if (widget.customEmojiBuilder != null && emoji.customData != null) {
        content = widget.customEmojiBuilder!(context, emoji.customData!, 28);
      } else {
        content = const Icon(Icons.error_outline, size: 20);
      }
    } else {
      content = Text(emoji.displayName, style: const TextStyle(fontSize: 28));
    }

    final hasVariations =
        emoji.type == PickerEmojiType.standard &&
        _variationsMap.containsKey(emoji.standardEmoji!.name);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _handleEmojiTap(emoji),
        onLongPress: hasVariations ? () {} : null,
        child: GestureDetector(
          onLongPressStart: (details) {
            if (hasVariations) {
              _showSkinToneMenu(context, emoji, details.globalPosition);
            }
          },
          child: Stack(
            children: [
              Center(
                child: FittedBox(fit: BoxFit.scaleDown, child: content),
              ),
              if (hasVariations)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
