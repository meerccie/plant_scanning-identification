import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/app_colors.dart';
import '../../components/plant_card.dart';
import '../../providers/plant_provider.dart';
import '../../services/supabase_service.dart';
import '../plant_details_page.dart';

class AllStoreListingsPage extends StatefulWidget {
  final String storeName;
  final List<Map<String, dynamic>> nonFeaturedPlants;

  const AllStoreListingsPage({
    super.key,
    required this.storeName,
    required this.nonFeaturedPlants,
  });

  @override
  State<AllStoreListingsPage> createState() => _AllStoreListingsPageState();
}

class _AllStoreListingsPageState extends State<AllStoreListingsPage> {
  late List<Map<String, dynamic>> _filteredPlants;
  final TextEditingController _searchController = TextEditingController();
  String _sortOrder = 'newest';

  @override
  void initState() {
    super.initState();
    _filteredPlants = List.from(widget.nonFeaturedPlants);
    _searchController.addListener(_filterPlants);
    _sortPlants();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterPlants);
    _searchController.dispose();
    super.dispose();
  }

  void _filterPlants() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPlants = widget.nonFeaturedPlants.where((plant) {
        final plantName = (plant['name'] as String? ?? '').toLowerCase();
        return plantName.contains(query);
      }).toList();
      _sortPlants();
    });
  }

  void _sortPlants() {
    switch (_sortOrder) {
      case 'a-z':
        _filteredPlants.sort((a, b) =>
            (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));
        break;
      case 'z-a':
        _filteredPlants.sort((a, b) =>
            (b['name'] as String? ?? '').compareTo(a['name'] as String? ?? ''));
        break;
      case 'oldest':
        _filteredPlants.sort((a, b) =>
            DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at'])));
        break;
      case 'newest':
      default:
        _filteredPlants.sort((a, b) =>
            DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = SupabaseService.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.storeName} Plants'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    elevation: 4.0,
                    borderRadius: BorderRadius.circular(12.0),
                    shadowColor: Colors.black.withOpacity(0.1),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search plants...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    setState(() {
                      _sortOrder = value;
                      _sortPlants();
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'newest',
                      child: Text('Newest First'),
                    ),
                    const PopupMenuItem(
                      value: 'oldest',
                      child: Text('Oldest First'),
                    ),
                    const PopupMenuItem(
                      value: 'a-z',
                      child: Text('A-Z'),
                    ),
                    const PopupMenuItem(
                      value: 'z-a',
                      child: Text('Z-A'),
                    ),
                  ],
                  icon: const Icon(Icons.sort, color: AppColors.primaryColor),
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: AppColors.backgroundColor,
      body: _filteredPlants.isEmpty
          ? const Center(child: Text('No plants found.'))
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              itemCount: _filteredPlants.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemBuilder: (context, index) {
                final plant = _filteredPlants[index];
                final plantId = plant['id']?.toString() ?? '';
                final isFavorite =
                    context.watch<PlantProvider>().isFavorite(plantId);
                final isOwner = plant['stores']?['user_id'] == currentUserId;

                return PlantCard(
                  title: plant['name'] ?? 'No Name',
                  subtitle: '₱${plant['price_range'] ?? 'N/A'}',
                  imageUrl: plant['image_url'],
                  isFavorite: isFavorite,
                  onFavoritePressed: isOwner
                      ? null
                      : () =>
                          context.read<PlantProvider>().toggleFavorite(plant),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PlantDetailsPage(plantId: plantId)),
                  ),
                );
              },
            ),
    );
  }
}
