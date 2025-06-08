import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/secure_storage_service.dart';
import '../../core/services/biometric_service.dart';
import '../../core/models/vault_item.dart';
import '../widgets/audio_player_widget.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final SecureStorageService _storageService = SecureStorageService.instance;
  final BiometricService _biometricService = BiometricService.instance;
  
  List<VaultItem> _vaultItems = [];
  List<VaultItem> _filteredItems = [];
  bool _isLoading = true;
  bool _isAuthenticated = false;
  String _searchQuery = '';
  VaultSortOption _sortOption = VaultSortOption.dateCreated;
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _authenticateAndLoadVault();
  }

  Future<void> _authenticateAndLoadVault() async {
    try {
      // Check if biometric authentication is required
      if (await _biometricService.isBiometricEnabled()) {
        final authResult = await _biometricService.authenticateForVault();
        if (!authResult) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      setState(() {
        _isAuthenticated = true;
      });

      await _loadVaultItems();
    } catch (e) {
      _showErrorSnackBar('Failed to authenticate: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadVaultItems() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final items = await _storageService.getVaultItems();
      setState(() {
        _vaultItems = items;
        _filteredItems = items;
        _isLoading = false;
      });

      _applySortAndFilter();
    } catch (e) {
      _showErrorSnackBar('Failed to load vault items: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applySortAndFilter() {
    setState(() {
      // Filter by search query
      _filteredItems = _vaultItems.where((item) {
        return item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               item.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               item.originalFileName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();

      // Sort items
      _filteredItems.sort((a, b) {
        int comparison;
        switch (_sortOption) {
          case VaultSortOption.name:
            comparison = a.name.compareTo(b.name);
            break;
          case VaultSortOption.dateCreated:
            comparison = a.createdAt.compareTo(b.createdAt);
            break;
          case VaultSortOption.dateModified:
            comparison = a.modifiedAt.compareTo(b.modifiedAt);
            break;
          case VaultSortOption.fileSize:
            comparison = a.fileSize.compareTo(b.fileSize);
            break;
        }
        return _sortAscending ? comparison : -comparison;
      });
    });
  }

  Future<void> _deleteVaultItem(VaultItem item) async {
    final confirmed = await _showDeleteConfirmation(item);
    if (!confirmed) return;

    try {
      await _storageService.removeVaultItem(item.id);
      await _loadVaultItems();
      _showSuccessSnackBar('${item.name} deleted successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to delete item: $e');
    }
  }

  Future<bool> _showDeleteConfirmation(VaultItem item) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _shareVaultItem(VaultItem item) async {
    try {
      final file = await _storageService.getVaultFile(item.fileName);
      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Shared from Covert Audio',
        );
      } else {
        _showErrorSnackBar('File not found');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to share item: $e');
    }
  }

  void _showVaultItemDetails(VaultItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => VaultItemDetailsSheet(item: item),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => VaultSortSheet(
        currentOption: _sortOption,
        ascending: _sortAscending,
        onSortChanged: (option, ascending) {
          setState(() {
            _sortOption = option;
            _sortAscending = ascending;
          });
          _applySortAndFilter();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Vault'),
        centerTitle: true,
        actions: [
          if (_isAuthenticated) ...[
            IconButton(
              onPressed: _showSortOptions,
              icon: const Icon(Icons.sort),
              tooltip: 'Sort options',
            ),
            IconButton(
              onPressed: _loadVaultItems,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!_isAuthenticated) {
      return _buildAuthenticationRequired(theme);
    }

    if (_vaultItems.isEmpty) {
      return _buildEmptyVault(theme);
    }

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search vault items...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
              _applySortAndFilter();
            },
          ),
        ),
        
        // Vault Stats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '${_filteredItems.length} item${_filteredItems.length == 1 ? '' : 's'}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              FutureBuilder<int>(
                future: _storageService.getVaultSize(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final sizeInMB = snapshot.data! / (1024 * 1024);
                    return Text(
                      '${sizeInMB.toStringAsFixed(1)} MB used',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Vault Items List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filteredItems.length,
            itemBuilder: (context, index) {
              final item = _filteredItems[index];
              return VaultItemCard(
                item: item,
                onTap: () => _showVaultItemDetails(item),
                onDelete: () => _deleteVaultItem(item),
                onShare: () => _shareVaultItem(item),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAuthenticationRequired(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Authentication Required',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Please authenticate to access your secure vault',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _authenticateAndLoadVault,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Authenticate'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyVault(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Vault is Empty',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first stego audio file by embedding a message in the Embed tab',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class VaultItemCard extends StatelessWidget {
  final VaultItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const VaultItemCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.audio_file,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          item.originalFileName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'share':
                          onShare();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share),
                            SizedBox(width: 8),
                            Text('Share'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  item.description,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.formattedCreatedAt,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item.formattedSize,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VaultItemDetailsSheet extends StatelessWidget {
  final VaultItem item;

  const VaultItemDetailsSheet({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Title
              Text(
                item.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Audio Player
              FutureBuilder<File>(
                future: SecureStorageService.instance.getVaultFile(item.fileName),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.existsSync()) {
                    return AudioPlayerWidget(audioFile: snapshot.data!);
                  }
                  return Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('Audio file not found'),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 24),
              
              // Details
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildDetailRow('Original File', item.originalFileName, theme),
                    _buildDetailRow('File Size', item.formattedSize, theme),
                    _buildDetailRow('Created', item.formattedCreatedAt, theme),
                    _buildDetailRow('Type', item.type.displayName, theme),
                    if (item.description.isNotEmpty)
                      _buildDetailRow('Description', item.description, theme),
                    if (item.metadata.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Metadata',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...item.metadata.entries.map(
                        (entry) => _buildDetailRow(
                          entry.key,
                          entry.value.toString(),
                          theme,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class VaultSortSheet extends StatelessWidget {
  final VaultSortOption currentOption;
  final bool ascending;
  final Function(VaultSortOption, bool) onSortChanged;

  const VaultSortSheet({
    super.key,
    required this.currentOption,
    required this.ascending,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sort Options',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 24),
          
          ...VaultSortOption.values.map((option) {
            return RadioListTile<VaultSortOption>(
              title: Text(option.displayName),
              value: option,
              groupValue: currentOption,
              onChanged: (value) {
                if (value != null) {
                  onSortChanged(value, ascending);
                }
              },
            );
          }),
          
          const Divider(),
          
          SwitchListTile(
            title: const Text('Ascending Order'),
            value: ascending,
            onChanged: (value) {
              onSortChanged(currentOption, value);
            },
          ),
          
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

enum VaultSortOption {
  name('Name'),
  dateCreated('Date Created'),
  dateModified('Date Modified'),
  fileSize('File Size');

  const VaultSortOption(this.displayName);
  final String displayName;
}

