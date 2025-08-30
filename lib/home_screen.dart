import 'dart:async';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xs_user/api_service.dart';
import 'package:xs_user/auth_service.dart';
import 'package:xs_user/canteen_detail_screen.dart';
import 'package:xs_user/cart_provider.dart';
import 'package:xs_user/cart_screen.dart';
import 'package:xs_user/initialization_service.dart';
import 'package:xs_user/login_screen.dart';
import 'package:xs_user/menu_provider.dart';
import 'package:xs_user/models.dart';
import 'package:xs_user/notifications_screen.dart';
import 'package:xs_user/orders_list_screen.dart';
import 'package:xs_user/profile_screen.dart';
import 'package:badges/badges.dart' as badges;
import 'package:xs_user/canteen_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late final InitializationService _initializationService;

  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreenBody(),
    OrdersListScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _initializationService =
        Provider.of<InitializationService>(context, listen: false);
    _initializationService.addListener(_onInitializationChange);
    _initializationService.initializeSupabaseAndGoogle();
  }

  @override
  void dispose() {
    _initializationService.removeListener(_onInitializationChange);
    super.dispose();
  }

  void _onInitializationChange() async {
    if (_initializationService.status == InitializationStatus.error) {
      _showErrorSnackbar("App initialization failed. Please restart.");
      return;
    }

    if (_initializationService.status == InitializationStatus.initialized) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      final bool isSessionValid = await AuthService.isGoogleSessionValid();
      if (!isSessionValid && mounted) {
        _showReLoginDialog();
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _signOut() async {
    await GoogleSignIn.instance.signOut();
    await Supabase.instance.client.auth.signOut();
  }

  void _showReLoginDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Session Expired"),
          content: const Text(
              "Your session has expired or access was revoked. Please sign in again."),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () async {
                await _signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                    (Route<dynamic> route) => false,
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor:
            Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        selectedItemColor:
            Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
        unselectedItemColor:
            Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
        selectedLabelStyle:
            GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.montserrat(),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}


class HomeScreenBody extends StatefulWidget {
  const HomeScreenBody({super.key});

  @override
  State<HomeScreenBody> createState() => HomeScreenBodyState();
}

enum SortOption {
  name,
  popularity,
  veg,
  nonVeg,
  priceAsc,
}

class HomeScreenBodyState extends State<HomeScreenBody> {
  Future<List<Item>>? _searchResults;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  SortOption _currentSortOption = SortOption.name;

  @override
  void initState() {
    super.initState();
    final canteenProvider = Provider.of<CanteenProvider>(context, listen: false);
    canteenProvider.fetchCanteens();
    canteenProvider.addListener(_onCanteensLoaded);

    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 200), () {
        if (_searchController.text.length >= 3) {
          setState(() {
            _searchResults = ApiService().searchItems(_searchController.text);
          });
        } else {
          setState(() {
            _searchResults = null;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    Provider.of<CanteenProvider>(context, listen: false).removeListener(_onCanteensLoaded);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onCanteensLoaded() {
    final canteenProvider = Provider.of<CanteenProvider>(context, listen: false);
    if (!canteenProvider.isLoading && canteenProvider.canteens.isNotEmpty) {
      final menuProvider = Provider.of<MenuProvider>(context, listen: false);
      for (var canteen in canteenProvider.canteens) {
        menuProvider.fetchMenuItems(canteen.id);
      }
    }
  }

  String getImageUrl(int canteenId) {
    return '${ApiService.baseUrl}/assets/canteen_$canteenId';
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sort By',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 16),
              _buildSortOptionTile('Default (Name)', SortOption.name),
              _buildSortOptionTile('Popularity', SortOption.popularity),
              _buildSortOptionTile('Price (Low to High)', SortOption.priceAsc),
              _buildSortOptionTile('Veg', SortOption.veg),
              _buildSortOptionTile('Non-Veg', SortOption.nonVeg),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOptionTile(String title, SortOption option) {
    return ListTile(
      title: Text(
        title,
        style: GoogleFonts.montserrat(
          color: _currentSortOption == option
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).textTheme.bodyMedium?.color,
          fontWeight:
              _currentSortOption == option ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: _currentSortOption == option
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () async {
        setState(() {
          _currentSortOption = option;
        });
        Navigator.pop(context);
        if (_searchResults != null) {
          List<Item> currentItems = await _searchResults!;
          setState(() {
            _searchResults = Future.value(_applySortToItems(currentItems));
          });
        }
      },
    );
  }

  List<Item> _applySortToItems(List<Item> items) {
    List<Item> availableItems =
        items.where((item) => item.isAvailable).toList();
    List<Item> unavailableItems =
        items.where((item) => !item.isAvailable).toList();

    Comparator<Item> comparator;

    switch (_currentSortOption) {
      case SortOption.name:
        comparator = (a, b) => a.name.compareTo(b.name);
        break;
      case SortOption.popularity:
        comparator = (a, b) => a.name.compareTo(b.name);
        break;
      case SortOption.priceAsc:
        comparator = (a, b) => a.price.compareTo(b.price);
        break;
      case SortOption.veg:
        availableItems = availableItems.where((item) => item.isVeg).toList();
        unavailableItems =
            unavailableItems.where((item) => item.isVeg).toList();
        comparator = (a, b) => a.name.compareTo(b.name);
        break;
      case SortOption.nonVeg:
        availableItems = availableItems.where((item) => !item.isVeg).toList();
        unavailableItems =
            unavailableItems.where((item) => !item.isVeg).toList();
        comparator = (a, b) => a.name.compareTo(b.name);
        break;
    }

    availableItems.sort(comparator);
    unavailableItems.sort(comparator);

    return [...availableItems, ...unavailableItems];
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning!';
    } else if (hour < 17) {
      return 'Good Afternoon!';
    } else {
      return 'Good Evening!';
    }
  }

  String _getRandomPhrase() {
    final phrases = [
      'Nanba iniku enna sapda poreenga?',
      'Nanba treat enga?',
      'Nanba sooda sapadu ready epo vaangureenga?',
      'Hungry? Find your favorite food!',
      'What are you craving today?',
      'Time to eat something delicious!',
      'Ready to order your favorite meal?',
      'Let\'s find something tasty for you!',
      'What\'s cooking today?',
      'Feeling hungry? Let\'s order something!',
      'What\'s on your plate today?',
      'Veg ah Non-Veg ah??',
    ];
    phrases.shuffle();
    return phrases.first;
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 80,
          backgroundColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).appBarTheme.backgroundColor,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: GoogleFonts.montserrat(
                        color: Theme.of(context).textTheme.titleLarge?.color,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getRandomPhrase(),
                      style: GoogleFonts.montserrat(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
              },
              icon: Icon(Icons.notifications_none_outlined,
                  color: Theme.of(context).iconTheme.color),
            ),
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
                    MaterialPageRoute(
                      builder: (context) => const CartScreen(),
                    ),
                  );
                },
                icon: Icon(Icons.shopping_cart_outlined,
                    color: Theme.of(context).iconTheme.color),
              ),
            ),
            SizedBox(width: 7)
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for food...',
                hintStyle: GoogleFonts.montserrat(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).iconTheme.color,
                  size: 20,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.clear,
                            color: Theme.of(context).iconTheme.color),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = null;
                            _currentSortOption = SortOption.name;
                          });
                        },
                      ),
                    Container(
                      margin: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFFF7A3A)
                            : Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        onPressed: _showFilterOptions,
                        icon: Icon(
                          Icons.filter_list,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _searchResults == null ? 'Campus Canteens' : 'Search Results',
                  style: GoogleFonts.montserrat(
                    color: Theme.of(context).textTheme.titleLarge?.color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_searchResults == null)
                  Consumer<CanteenProvider>(
                    builder: (context, canteenProvider, child) {
                      if (canteenProvider.isLoading && canteenProvider.canteens.isEmpty) {
                        return const SizedBox();
                      }
                      return Text(
                        '${canteenProvider.canteens.length} canteens available',
                        style: GoogleFonts.montserrat(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        _searchResults != null ? _buildSearchResults() : _buildCanteenList(),
      ],
    );
  }

  Widget _buildCanteenList() {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: Consumer<CanteenProvider>(
        builder: (context, canteenProvider, child) {
          if (canteenProvider.isLoading && canteenProvider.canteens.isEmpty) {
            return const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (canteenProvider.canteens.isEmpty) {
            return SliverToBoxAdapter(
              child: Center(
                  child: Text('No canteens found.',
                      style: TextStyle(
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color))),
            );
          }

          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final canteen = canteenProvider.canteens[index];
                return _buildCanteenCard(context, canteen);
              },
              childCount: canteenProvider.canteens.length,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: FutureBuilder<List<Item>>(
        future: _searchResults,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasError) {
            return SliverToBoxAdapter(
              child: Center(child: Text('Error: ${snapshot.error}')),
            );
          } else if (snapshot.hasData) {
            List<Item> items = snapshot.data!;
            items = _applySortToItems(items);
            if (items.isEmpty) {
              return const SliverToBoxAdapter(
                child: Center(child: Text('No items found.')),
              );
            }
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = items[index];
                  final canteens = Provider.of<CanteenProvider>(context, listen: false).canteens;
                  final canteen = canteens.firstWhere(
                      (c) => c.id == item.canteenId,
                      orElse: () => Canteen(
                          id: 0,
                          name: 'Unknown',
                          location: '',
                          rating: 0,
                          etag: null,
                          pic: null));
                  return _buildMenuItem(item: item, canteenName: canteen.name);
                },
                childCount: items.length,
              ),
            );
          } else {
            return const SliverToBoxAdapter(
              child:
                  Center(child: Text('Search for something to get results.')),
            );
          }
        },
      ),
    );
  }

  Widget _buildMenuItem({required Item item, required String canteenName}) {
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        final cartItem = cart.items.containsKey(item.id.toString())
            ? cart.items[item.id.toString()]
            : null;
        final bool canAddItem = item.isAvailable && item.stock > 0;

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
                          Colors.transparent, BlendMode.multiply)
                      : ColorFilter.mode(Colors.black.withAlpha((255 * 0.9).round()),
                          BlendMode.saturation),
                  child: Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey.withAlpha((255 * 0.1).round()),
                    child: Stack(
                      children: [
                        Image.asset(
                          item.isVeg
                              ? 'assets/veg.jpg'
                              : 'assets/non_veg.jpg',
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
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
                                        165, 255, 255, 255),
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
                        if (item.isVeg)
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1BB05A),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.eco,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        if (item.isVeg) const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            item.name,
                            style: GoogleFonts.montserrat(
                              color:
                                  Theme.of(context).textTheme.titleLarge?.color,
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
                      canteenName,
                      style: GoogleFonts.montserrat(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description ?? '',
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
                            cart.addItem(
                                item.id.toString(),
                                item.name,
                                item.price,
                                item.canteenId,
                                item.pic,
                                item.etag,
                                item.isVeg,
                                item.stock);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                            elevation: 4,
                          ),
                          child: Icon(Icons.add,
                              color: Theme.of(context).colorScheme.onPrimary),
                        ),
                      )
                    : Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              cart.removeSingleItem(item.id.toString());
                            },
                            icon: Icon(Icons.remove_circle_outline,
                                color: Theme.of(context).iconTheme.color),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            cartItem.quantity.toString(),
                            style: GoogleFonts.montserrat(
                              color: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.color,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () {
                              cart.addItem(
                                  item.id.toString(),
                                  item.name,
                                  item.price,
                                  item.canteenId,
                                  item.pic,
                                  item.etag,
                                  item.isVeg,
                                  item.stock);
                            },
                            icon: Icon(Icons.add_circle_outline,
                                color: Theme.of(context).colorScheme.primary),
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
}

Widget _buildCanteenCard(BuildContext context, Canteen canteen) {
  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CanteenDetailScreen(canteen: canteen),
        ),
      );
    },
    child: Hero(
      tag: 'canteen_image_${canteen.id}',
      child: Container(
        height: 220,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 6),
              blurRadius: 20,
              color:
                  Theme.of(context).colorScheme.onSurface.withAlpha((255 * 0.1).round()),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Center(
                child: (canteen.pic != null)? ExtendedImage.network(canteen.pic!, 
                  cacheKey: canteen.etag,
                  cache: true,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ):
                Icon(Icons.store),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(153),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(128),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        canteen.rating.toStringAsFixed(1),
                        style:
                            GoogleFonts.montserrat(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      canteen.name,
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            blurRadius: 10.0,
                            color: Colors.black,
                            offset: Offset(5.0, 5.0),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      canteen.location,
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 14,
                        shadows: [
                          Shadow(
                            blurRadius: 10.0,
                            color: Colors.black,
                            offset: Offset(5.0, 5.0),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFFF7A3A)
                            : Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Open',
                        style: GoogleFonts.montserrat(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
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
  );
}