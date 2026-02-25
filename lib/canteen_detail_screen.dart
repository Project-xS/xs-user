import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import 'package:xs_user/cart_provider.dart';
import 'package:xs_user/cart_screen.dart';
import 'package:xs_user/models.dart';
import 'package:xs_user/menu_provider.dart';

class CanteenDetailScreen extends StatefulWidget {
  final Canteen canteen;

  const CanteenDetailScreen({super.key, required this.canteen});

  @override
  State<CanteenDetailScreen> createState() => _CanteenDetailScreenState();
}

enum SortOption { name, popularity, priceAsc, veg, nonVeg }

class _CanteenDetailScreenState extends State<CanteenDetailScreen> {
  SortOption _currentSortOption = SortOption.name;
  late MenuProvider _menuProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _menuProvider.setActiveCanteen(widget.canteen.id);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _menuProvider = Provider.of<MenuProvider>(context, listen: false);
  }

  @override
  void dispose() {
    // Stop auto-refresh when leaving this screen
    _menuProvider.setActiveCanteen(null);
    super.dispose();
  }

  List<Item> _applySortToItems(List<Item> items) {
    List<Item> availableItems = items
        .where((item) => item.isAvailable)
        .toList();
    List<Item> unavailableItems = items
        .where((item) => !item.isAvailable)
        .toList();

    Comparator<Item> comparator;

    switch (_currentSortOption) {
      case SortOption.name:
        comparator = (a, b) => a.name.compareTo(b.name);
        break;
      case SortOption.popularity:
        // TODO: Items don't have popularity for now.
        comparator = (a, b) => a.name.compareTo(b.name);
        break;
      case SortOption.priceAsc:
        comparator = (a, b) => a.price.compareTo(b.price);
        break;
      case SortOption.veg:
        availableItems = availableItems.where((item) => item.isVeg).toList();
        unavailableItems = unavailableItems
            .where((item) => item.isVeg)
            .toList();
        comparator = (a, b) => a.name.compareTo(b.name);
        break;
      case SortOption.nonVeg:
        availableItems = availableItems.where((item) => !item.isVeg).toList();
        unavailableItems = unavailableItems
            .where((item) => !item.isVeg)
            .toList();
        comparator = (a, b) => a.name.compareTo(b.name);
        break;
    }

    availableItems.sort(comparator);
    unavailableItems.sort(comparator);

    return [...availableItems, ...unavailableItems];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: Theme.of(context).iconTheme.color,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.canteen.name,
          style: GoogleFonts.montserrat(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Consumer<CartProvider>(
            builder: (_, cart, ch) => badges.Badge(
              badgeContent: Text(
                cart.itemCount.toString(),
                style: const TextStyle(color: Colors.white),
              ),
              position: badges.BadgePosition.topEnd(top: 0, end: 3),
              child: ch,
            ),
            child: IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CartScreen()),
                );
              },
              icon: Icon(
                Icons.shopping_cart_outlined,
                color: Theme.of(context).iconTheme.color,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Hero(
            tag: 'canteen_image_${widget.canteen.id}',
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  (widget.canteen.pic != null)
                      ? ExtendedImage.network(
                          widget.canteen.pic!,
                          cache: true,
                          cacheKey: widget.canteen.etag,
                          clearMemoryCacheIfFailed: false,
                          fit: BoxFit.cover,
                        )
                      : Center(child: Icon(Icons.store)),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withAlpha((255 * 0.7).round()),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.canteen.name,
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.canteen.location,
                          style: GoogleFonts.montserrat(
                            color: Colors.white.withAlpha((255 * 0.9).round()),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Color(0xFFFFCB44),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.canteen.rating.toString(),
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  TabBar(
                    labelColor: const Color(0xFFFF7A3A),
                    unselectedLabelColor: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color,
                    indicatorColor: const Color(0xFFFF7A3A),
                    tabs: const [
                      Tab(text: 'Menu'),
                      Tab(text: 'Reviews'),
                      Tab(text: 'Info'),
                    ],
                  ),

                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildMenuTab(context),
                        _buildReviewsTab(context),
                        _buildInfoTab(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTab(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DropdownButton<SortOption>(
                value: _currentSortOption,
                icon: Icon(
                  Icons.sort,
                  color: Theme.of(context).iconTheme.color,
                ),
                underline: Container(),
                focusColor: Colors.transparent,
                onChanged: (SortOption? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _currentSortOption = newValue;
                    });
                  }
                },
                items:
                    const <DropdownMenuItem<SortOption>>[
                      DropdownMenuItem(
                        value: SortOption.name,
                        child: Text('Sort by Name'),
                      ),
                      DropdownMenuItem(
                        value: SortOption.popularity,
                        child: Text('Sort by Popularity'),
                      ),
                      DropdownMenuItem(
                        value: SortOption.priceAsc,
                        child: Text('Sort by Price (Low to High)'),
                      ),
                      DropdownMenuItem(
                        value: SortOption.veg,
                        child: Text('Sort by Vegetarian'),
                      ),
                      DropdownMenuItem(
                        value: SortOption.nonVeg,
                        child: Text('Sort by Non-Vegetarian'),
                      ),
                    ].map<DropdownMenuItem<SortOption>>((
                      DropdownMenuItem<SortOption> item,
                    ) {
                      return DropdownMenuItem<SortOption>(
                        value: item.value,
                        child: Text(
                          item.child is Text ? (item.child as Text).data! : '',
                          style: GoogleFonts.montserrat(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ],
          ),
        ),
        Expanded(
          child: Consumer<MenuProvider>(
            builder: (context, menuProvider, child) {
              if (menuProvider.isLoading(widget.canteen.id) &&
                  menuProvider.getMenuItems(widget.canteen.id).isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (menuProvider.getMenuItems(widget.canteen.id).isEmpty) {
                return const Center(child: Text('No items found.'));
              }

              List<Item> items = _applySortToItems(
                menuProvider.getMenuItems(widget.canteen.id),
              );
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _buildMenuItem(
                    item: item,
                    canteenId: widget.canteen.id,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsTab(BuildContext context) {
    return Consumer<MenuProvider>(
      builder: (context, menuProvider, child) {
        if (menuProvider.isLoading(widget.canteen.id) &&
            menuProvider.getMenuItems(widget.canteen.id).isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (menuProvider.getMenuItems(widget.canteen.id).isEmpty) {
          return const Center(child: Text('No reviews found.'));
        }

        final items = menuProvider.getMenuItems(widget.canteen.id);
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final Item item = items[index % items.length];
            return Card(
              color: Theme.of(context).cardColor,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: (item.pic != null)
                              ? ExtendedImage.network(
                                  item.pic!,
                                  cache: true,
                                  cacheKey: item.etag,
                                  width: 50,
                                  height: 50,
                                )
                              : Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.grey.withAlpha(
                                    (255 * 0.1).round(),
                                  ),
                                  child: Icon(
                                    Icons.fastfood,
                                    color: Theme.of(context).iconTheme.color,
                                    size: 20,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.name,
                            style: GoogleFonts.montserrat(
                              color: Theme.of(
                                context,
                              ).textTheme.titleLarge?.color,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          Icons.star,
                          color: i < 4
                              ? const Color(0xFFFFCB44)
                              : Theme.of(context).iconTheme.color?.withAlpha(
                                  (255 * 0.5).round(),
                                ),
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This is a great dish! Highly recommended.',
                      style: GoogleFonts.montserrat(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        'Located at ${widget.canteen.location}',
        style: GoogleFonts.montserrat(
          color: Theme.of(context).textTheme.titleLarge?.color,
          fontSize: 16,
        ),
      ),
    );
  }
}

Widget _buildMenuItem({required Item item, required int canteenId}) {
  return Consumer<CartProvider>(
    builder: (context, cart, child) {
      final cartItem = cart.items.containsKey(item.id.toString())
          ? cart.items[item.id.toString()]
          : null;
      final bool canAddItem =
          item.isAvailable && (item.stock > 0 || item.stock == -1);

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColorFiltered(
                colorFilter: item.isAvailable
                    ? const ColorFilter.mode(
                        Colors.transparent,
                        BlendMode.multiply,
                      )
                    : ColorFilter.mode(Colors.black, BlendMode.saturation),
                child: Container(
                  width: 70,
                  height: 70,
                  color: Colors.grey.withAlpha((255 * 0.1).round()),
                  child: Stack(
                    children: [
                      (item.pic != null)
                          ? ExtendedImage.network(
                              item.pic!,
                              cacheKey: item.etag,
                              cache: true,
                              clearMemoryCacheIfFailed: false,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                            )
                          : Center(
                              child: Icon(
                                Icons.fastfood,
                                color: item.isAvailable
                                    ? (Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white
                                          : Theme.of(
                                              context,
                                            ).colorScheme.primary)
                                    : Theme.of(context).iconTheme.color,
                                size: 30,
                              ),
                            ),
                      if (!item.isAvailable)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withAlpha((255 * 0.6).round()),
                            child: Center(
                              child: Text(
                                'Out of Stock',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.montserrat(
                                  color: const Color.fromARGB(
                                    165,
                                    255,
                                    255,
                                    255,
                                  ),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: (item.isVeg) ? Color(0xFF1BB05A) : Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          (item.isVeg) ? Icons.eco : Icons.kebab_dining,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          item.name,
                          style: GoogleFonts.montserrat(
                            color: Theme.of(
                              context,
                            ).textTheme.titleLarge?.color,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (item.stock == -1)
                        ? "Available"
                        : "${(item.isAvailable) ? item.stock : 0} items left",
                    style: GoogleFonts.montserrat(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${item.price.toStringAsFixed(0)}',
                    style: GoogleFonts.montserrat(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (canAddItem)
              cartItem == null
                  ? SizedBox(
                      width: 40,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () {
                          if (cartItem == null || cartItem.quantity < 20) {
                            cart.addItem(
                              item.id.toString(),
                              item.name,
                              item.price,
                              canteenId,
                              item.pic,
                              item.etag,
                              item.isVeg,
                              item.stock,
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'You can only add up to 20 of each item.',
                                ),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          shape: const CircleBorder(),
                          padding: EdgeInsets.zero,
                          elevation: 4,
                        ),
                        child: Icon(
                          Icons.add,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            cart.removeSingleItem(item.id.toString());
                          },
                          icon: Icon(
                            Icons.remove_circle_outline,
                            color: Theme.of(context).iconTheme.color,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          cartItem.quantity.toString(),
                          style: GoogleFonts.montserrat(
                            color: Theme.of(
                              context,
                            ).textTheme.titleMedium?.color,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            if (cartItem.quantity < 20) {
                              cart.addItem(
                                item.id.toString(),
                                item.name,
                                item.price,
                                canteenId,
                                item.pic,
                                item.etag,
                                item.isVeg,
                                item.stock,
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'You can only add up to 20 of each item.',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: Icon(
                            Icons.add_circle_outline,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    )
            else
              Text(
                'Unavailable',
                style: GoogleFonts.montserrat(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      );
    },
  );
}
