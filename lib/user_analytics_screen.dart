import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'order_provider.dart';
import 'models.dart';

class UserAnalyticsScreen extends StatelessWidget {
  const UserAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Analytics')),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, child) {
          if (orderProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (orderProvider.error != null) {
            return Center(child: Text('Error: ${orderProvider.error}'));
          }

          if (orderProvider.orderResponse == null ||
              orderProvider.orderResponse!.data.isEmpty) {
            return const Center(child: Text('No orders found.'));
          }

          final completedOrders = orderProvider.orderResponse!.data
              .where((order) => order.orderStatus)
              .toList();

          if (completedOrders.isEmpty) {
            return const Center(child: Text('No completed orders found.'));
          }

          return _buildAnalytics(context, completedOrders);
        },
      ),
    );
  }

  Widget _buildAnalytics(BuildContext context, List<Order> completedOrders) {
    final monthlyOrderedValue = _calculateMonthlyOrderedValue(completedOrders);
    final vegNonVegCount = _calculateVegNonVegCount(completedOrders);
    final mostOrderedItem = _getMostOrderedItem(completedOrders);
    final timeSaved = _calculateTimeSaved(completedOrders);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildMonthlyValueChart(context, monthlyOrderedValue),
        const SizedBox(height: 24),
        _buildVegNonVegChart(context, vegNonVegCount),
        const SizedBox(height: 24),
        _buildMostOrderedItem(context, mostOrderedItem),
        const SizedBox(height: 24),
        _buildTimeSaved(context, timeSaved),
      ],
    );
  }

  Map<String, double> _calculateMonthlyOrderedValue(List<Order> orders) {
    final Map<String, double> monthlyValues = {};
    for (var order in orders) {
      final month = DateFormat('MMM').format(order.orderedAtDateTime);
      monthlyValues.update(
        month,
        (value) => value + order.totalPrice,
        ifAbsent: () => order.totalPrice.toDouble(),
      );
    }
    return monthlyValues;
  }

  Map<String, int> _calculateVegNonVegCount(List<Order> orders) {
    int vegCount = 0;
    int nonVegCount = 0;
    for (var order in orders) {
      for (var item in order.items) {
        if (item.isVeg) {
          vegCount += item.quantity;
        } else {
          nonVegCount += item.quantity;
        }
      }
    }
    return {'Veg': vegCount, 'Non-Veg': nonVegCount};
  }

  String _getMostOrderedItem(List<Order> orders) {
    final Map<String, int> itemCounts = {};
    for (var order in orders) {
      for (var item in order.items) {
        itemCounts.update(
          item.name,
          (value) => value + item.quantity,
          ifAbsent: () => item.quantity,
        );
      }
    }
    if (itemCounts.isEmpty) {
      return 'N/A';
    }
    return itemCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  int _calculateTimeSaved(List<Order> orders) {
    // Estimate ~25 minutes saved per order (avg queue wait time)
    return orders.length * 25;
  }

  Widget _buildMonthlyValueChart(
    BuildContext context,
    Map<String, double> monthlyData,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Order Value - ${DateTime.now().year}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 25),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                height: 210,
                width: max(
                  MediaQuery.of(context).size.width - 75,
                  monthlyData.length * 55.0,
                ),
                child: BarChart(
                  BarChartData(
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    alignment: BarChartAlignment.spaceAround,
                    maxY:
                        (monthlyData.values.isEmpty
                            ? 0
                            : monthlyData.values.reduce(
                                (a, b) => a > b ? a : b,
                              )) *
                        1.2,
                    barGroups: monthlyData.entries.map((entry) {
                      final index = monthlyData.keys.toList().indexOf(
                        entry.key,
                      );
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).primaryColor,
                            width: 16,
                          ),
                        ],
                      );
                    }).toList(),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Text(
                                NumberFormat.compact().format(value),
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < monthlyData.keys.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  monthlyData.keys.toList()[index],
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }
                            return const Text('');
                          },
                          reservedSize: 40,
                        ),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVegNonVegChart(
    BuildContext context,
    Map<String, int> vegNonVegData,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Veg vs Non-Veg',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 35),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: vegNonVegData.entries.map((entry) {
                    final isVeg = entry.key == 'Veg';
                    return PieChartSectionData(
                      color: isVeg ? Colors.green : Colors.red,
                      value: entry.value.toDouble(),
                      title: '${entry.key}\n(${entry.value})',
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  Widget _buildMostOrderedItem(BuildContext context, String mostOrderedItem) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Most Ordered Item',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                mostOrderedItem,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final hoursString = hours > 0
        ? '$hours ${hours == 1 ? 'hour' : 'hours'}'
        : '';
    final minutesString = minutes > 0
        ? '$minutes ${minutes == 1 ? 'minute' : 'minutes'}'
        : '';
    return [hoursString, minutesString].where((s) => s.isNotEmpty).join(' ');
  }

  Widget _buildTimeSaved(BuildContext context, int timeSaved) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Time Saved', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _formatDuration(timeSaved),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'by ordering with us!',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
