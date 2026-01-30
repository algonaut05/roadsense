import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../core/services/municipality_auth_service.dart';

/// Municipality Admin Dashboard
/// Shows statistics, issues, and management tools for municipal admins
class MunicipalityDashboardScreen extends StatefulWidget {
  final MunicipalityAuthService authService;
  final VoidCallback onLogout;

  const MunicipalityDashboardScreen({
    Key? key,
    required this.authService,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<MunicipalityDashboardScreen> createState() =>
      _MunicipalityDashboardScreenState();
}

class _MunicipalityDashboardScreenState
    extends State<MunicipalityDashboardScreen> {
  late FirebaseFirestore _firestore;
  String _selectedFilter = 'all'; // all, open, resolved, high_priority
  bool _isLoading = true;

  int _totalPotholes = 0;
  int _openIssues = 0;
  int _resolvedIssues = 0;
  int _highPriority = 0;
  List<IssueData> _issues = [];

  @override
  void initState() {
    super.initState();
    _firestore = FirebaseFirestore.instanceFor(
      databaseId: 'roadse',
      app: Firebase.app(),
    );
    _loadDashboardData();
  }

  /// Load all dashboard statistics
  Future<void> _loadDashboardData() async {
    try {
      // Get current user's municipality
      final user = widget.authService.currentUser;
      if (user == null) return;

      // Query municipality issues
      final issuesSnapshot = await _firestore
          .collection('municipality_issues')
          .where('municipality_id', isEqualTo: user.municipalityId)
          .get();

      int totalCount = 0;
      int openCount = 0;
      int resolvedCount = 0;
      int highCount = 0;
      List<IssueData> issuesList = [];

      for (var doc in issuesSnapshot.docs) {
        final data = doc.data();
        totalCount++;

        final status = data['status'] as String? ?? 'OPEN';
        final priority = data['priority'] as String? ?? 'MEDIUM';
        final severity = data['severity'] as int? ?? 1;

        if (status == 'OPEN') openCount++;
        if (status == 'RESOLVED') resolvedCount++;
        if (priority == 'HIGH') highCount++;

        issuesList.add(
          IssueData(
            id: doc.id,
            status: status,
            severity: severity,
            priority: priority,
            latitude: data['latitude'] as double? ?? 0,
            longitude: data['longitude'] as double? ?? 0,
            assignedTo: data['assigned_to'] as String?,
            createdAt: (data['created_at'] as Timestamp?)?.toDate(),
            detectionId: data['detection_id'] as String? ?? 'N/A',
          ),
        );
      }

      setState(() {
        _totalPotholes = totalCount;
        _openIssues = openCount;
        _resolvedIssues = resolvedCount;
        _highPriority = highCount;
        _issues = issuesList;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  /// Filter issues based on selected filter
  List<IssueData> _getFilteredIssues() {
    switch (_selectedFilter) {
      case 'open':
        return _issues.where((i) => i.status == 'OPEN').toList();
      case 'resolved':
        return _issues.where((i) => i.status == 'RESOLVED').toList();
      case 'high_priority':
        return _issues.where((i) => i.priority == 'HIGH').toList();
      default:
        return _issues;
    }
  }

  /// Get severity label
  String _getSeverityLabel(int severity) {
    switch (severity) {
      case 3:
        return 'High';
      case 2:
        return 'Medium';
      case 1:
      default:
        return 'Low';
    }
  }

  /// Get severity color
  Color _getSeverityColor(int severity) {
    switch (severity) {
      case 3:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 1:
      default:
        return Colors.yellow;
    }
  }

  /// Get status badge color
  Color _getStatusColor(String status) {
    switch (status) {
      case 'OPEN':
        return Colors.blue;
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'RESOLVED':
        return Colors.green;
      case 'CLOSED':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  /// Logout user
  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await widget.authService.logout();
              if (mounted) {
                widget.onLogout();
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Municipality Dashboard'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // User info banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.blue.shade400,
                            Colors.blue.shade700,
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.admin_panel_settings,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user?.name ?? 'Admin',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      user?.email ?? '',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Statistics cards
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Statistics',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            children: [
                              _StatCard(
                                title: 'Total Issues',
                                value: _totalPotholes.toString(),
                                icon: Icons.warning,
                                color: Colors.red,
                              ),
                              _StatCard(
                                title: 'Open Issues',
                                value: _openIssues.toString(),
                                icon: Icons.assignment,
                                color: Colors.blue,
                              ),
                              _StatCard(
                                title: 'Resolved',
                                value: _resolvedIssues.toString(),
                                icon: Icons.check_circle,
                                color: Colors.green,
                              ),
                              _StatCard(
                                title: 'High Priority',
                                value: _highPriority.toString(),
                                icon: Icons.priority_high,
                                color: Colors.orange,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Filter section
                          const Text(
                            'Issues',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _FilterChip(
                                  label: 'All',
                                  isSelected: _selectedFilter == 'all',
                                  onTap: () => setState(
                                    () => _selectedFilter = 'all',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _FilterChip(
                                  label: 'Open',
                                  isSelected: _selectedFilter == 'open',
                                  onTap: () => setState(
                                    () => _selectedFilter = 'open',
                                  ),
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 8),
                                _FilterChip(
                                  label: 'Resolved',
                                  isSelected: _selectedFilter == 'resolved',
                                  onTap: () => setState(
                                    () => _selectedFilter = 'resolved',
                                  ),
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 8),
                                _FilterChip(
                                  label: 'High Priority',
                                  isSelected: _selectedFilter == 'high_priority',
                                  onTap: () => setState(
                                    () => _selectedFilter = 'high_priority',
                                  ),
                                  color: Colors.orange,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Issues list
                          if (_getFilteredIssues().isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 32,
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.done_all,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No issues found',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _getFilteredIssues().length,
                              itemBuilder: (context, index) {
                                final issue = _getFilteredIssues()[index];
                                return _IssueCard(
                                  issue: issue,
                                  severityColor:
                                      _getSeverityColor(issue.severity),
                                  severityLabel:
                                      _getSeverityLabel(issue.severity),
                                  statusColor: _getStatusColor(issue.status),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Statistics card widget
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Filter chip widget
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/// Issue card widget
class _IssueCard extends StatelessWidget {
  final IssueData issue;
  final Color severityColor;
  final String severityLabel;
  final Color statusColor;

  const _IssueCard({
    required this.issue,
    required this.severityColor,
    required this.severityLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Severity indicator
          Container(
            width: 4,
            height: 60,
            decoration: BoxDecoration(
              color: severityColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // Issue info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Issue #${issue.id.substring(0, 8)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        issue.status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Severity: $severityLabel',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      'Priority: ${issue.priority}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Location: ${issue.latitude.toStringAsFixed(4)}, ${issue.longitude.toStringAsFixed(4)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Action icon
          Icon(
            Icons.arrow_forward,
            color: Colors.grey.shade400,
            size: 20,
          ),
        ],
      ),
    );
  }
}

/// Issue data model
class IssueData {
  final String id;
  final String status;
  final int severity;
  final String priority;
  final double latitude;
  final double longitude;
  final String? assignedTo;
  final DateTime? createdAt;
  final String detectionId;

  IssueData({
    required this.id,
    required this.status,
    required this.severity,
    required this.priority,
    required this.latitude,
    required this.longitude,
    this.assignedTo,
    this.createdAt,
    required this.detectionId,
  });
}
