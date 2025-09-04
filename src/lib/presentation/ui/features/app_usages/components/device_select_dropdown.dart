import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/core/application/features/app_usages/queries/get_distinct_device_names_query.dart';
import 'dart:async';
import 'package:whph/presentation/ui/shared/utils/responsive_dialog_helper.dart';

class DeviceSelectDropdown extends StatefulWidget {
  final List<DropdownOption<String>> initialSelectedDevices;
  final bool isMultiSelect;
  final IconData icon;
  final String? buttonLabel;
  final double? iconSize;
  final Color? color;
  final String? tooltip;
  final bool showLength;
  final bool showNoneOption;
  final bool initialNoneSelected;
  final Function(List<DropdownOption<String>>, bool isNoneSelected) onDevicesSelected;

  const DeviceSelectDropdown({
    super.key,
    this.initialSelectedDevices = const [],
    required this.isMultiSelect,
    this.icon = Icons.devices,
    this.buttonLabel,
    this.iconSize = AppTheme.iconSizeMedium,
    this.color,
    this.tooltip,
    required this.onDevicesSelected,
    this.showLength = false,
    this.showNoneOption = false,
    this.initialNoneSelected = false,
  });

  @override
  State<DeviceSelectDropdown> createState() => _DeviceSelectDropdownState();
}

class _DeviceSelectDropdownState extends State<DeviceSelectDropdown> {
  final Mediator _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  List<String> _availableDevices = [];

  List<String> _selectedDevices = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  bool _hasExplicitlySelectedNone = false;
  bool _needsStateUpdate = false;

  @override
  void initState() {
    _selectedDevices = widget.initialSelectedDevices.map((e) => e.value).toList();
    _hasExplicitlySelectedNone = widget.showNoneOption && (_selectedDevices.isEmpty && widget.initialNoneSelected);

    if (_hasExplicitlySelectedNone) {
      _selectedDevices.clear();
    }

    _getDevices();
    super.initState();
  }

  @override
  void didUpdateWidget(DeviceSelectDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_selectedDevicesChanged(oldWidget.initialSelectedDevices, widget.initialSelectedDevices)) {
      _selectedDevices = widget.initialSelectedDevices.map((e) => e.value).toList();
      _needsStateUpdate = true;
    }

    if (oldWidget.initialNoneSelected != widget.initialNoneSelected) {
      _hasExplicitlySelectedNone = widget.showNoneOption && (_selectedDevices.isEmpty && widget.initialNoneSelected);

      if (_hasExplicitlySelectedNone) {
        _selectedDevices.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onDevicesSelected(const [], true);
          }
        });
      }
      _needsStateUpdate = true;
    }

    if (_needsStateUpdate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _needsStateUpdate = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  bool _selectedDevicesChanged(List<DropdownOption<String>> oldDevices, List<DropdownOption<String>> newDevices) {
    if (oldDevices.length != newDevices.length) {
      return true;
    }

    final oldValues = oldDevices.map((e) => e.value).toSet();
    final newValues = newDevices.map((e) => e.value).toSet();

    return oldValues.union(newValues).length != oldValues.length;
  }

  Future<void> _getDevices() async {
    await AsyncErrorHandler.execute<GetDistinctDeviceNamesQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(AppUsageTranslationKeys.getUsageError),
      operation: () async {
        final query = GetDistinctDeviceNamesQuery();
        return await _mediator.send<GetDistinctDeviceNamesQuery, GetDistinctDeviceNamesQueryResponse>(query);
      },
      onSuccess: (result) {
        if (mounted) {
          setState(() {
            _availableDevices = result.deviceNames;
            _selectedDevices = widget.initialSelectedDevices
                .where((device) => result.deviceNames.contains(device.value))
                .map((e) => e.value)
                .toList();
          });
        }
      },
    );
  }

  Future<void> _showDeviceSelectionModal(BuildContext context) async {
    List<String> tempSelectedDevices = List<String>.from(_selectedDevices);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });

    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final filteredDevices = _availableDevices.where((device) {
            final searchTerm = _searchController.text.toLowerCase();
            return device.toLowerCase().contains(searchTerm);
          }).toList();

          return Scaffold(
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
              backgroundColor: Theme.of(context).cardColor,
              title: Text(_translationService.translate(AppUsageTranslationKeys.deviceLabel)),
              automaticallyImplyLeading: false,
              actions: [
                if (tempSelectedDevices.isNotEmpty || _hasExplicitlySelectedNone)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        tempSelectedDevices.clear();
                        _hasExplicitlySelectedNone = false;
                      });
                    },
                    icon: Icon(SharedUiConstants.clearIcon),
                    tooltip: _translationService.translate(AppUsageTranslationKeys.clearAllButton),
                  ),
                TextButton(
                  onPressed: () => _confirmDeviceSelection(tempSelectedDevices),
                  child: Text(_translationService.translate(SharedTranslationKeys.doneButton)),
                ),
                const SizedBox(width: AppTheme.sizeSmall),
              ],
            ),
            body: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SafeArea(
                child: Column(
                  children: [
                    // Search Section
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          labelText: _translationService.translate(AppUsageTranslationKeys.searchLabel),
                          fillColor: Colors.transparent,
                          labelStyle: AppTheme.bodySmall,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (value) {
                          if (!mounted) return;
                          setState(() {});
                        },
                      ),
                    ),

                    // Device List Section
                    Expanded(
                      child: ListView.builder(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: filteredDevices.length + (widget.showNoneOption ? 2 : 0),
                        itemBuilder: (context, index) {
                          if (widget.showNoneOption && index == 0) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Text(
                                _translationService.translate(SharedTranslationKeys.specialFiltersLabel),
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                              ),
                            );
                          }

                          if (widget.showNoneOption && index == 1) {
                            return CheckboxListTile(
                              title: Text(
                                _translationService.translate(SharedTranslationKeys.noneOption),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              value: _hasExplicitlySelectedNone,
                              onChanged: (bool? value) {
                                if (!mounted) return;
                                setState(() {
                                  if (value == true) {
                                    tempSelectedDevices.clear();
                                    _hasExplicitlySelectedNone = true;
                                  } else {
                                    _hasExplicitlySelectedNone = false;
                                  }
                                });
                              },
                            );
                          }

                          final actualIndex = widget.showNoneOption ? index - 2 : index;

                          if (actualIndex < 0 || actualIndex >= filteredDevices.length) {
                            return const SizedBox.shrink();
                          }

                          final device = filteredDevices[actualIndex];
                          return CheckboxListTile(
                            title: Text(device),
                            value: tempSelectedDevices.contains(device),
                            onChanged: (bool? value) {
                              if (!mounted) return;
                              setState(() {
                                if (value == true && _hasExplicitlySelectedNone) {
                                  _hasExplicitlySelectedNone = false;
                                }

                                if (widget.isMultiSelect) {
                                  if (value == true) {
                                    tempSelectedDevices.add(device);
                                  } else {
                                    tempSelectedDevices.remove(device);
                                  }
                                } else {
                                  tempSelectedDevices.clear();
                                  if (value == true) {
                                    tempSelectedDevices.add(device);
                                  }
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeviceSelection(List<String> tempSelectedDevices) {
    if (mounted) {
      setState(() {
        _selectedDevices = List<String>.from(tempSelectedDevices);
      });
    }

    final isNoneSelected = _hasExplicitlySelectedNone;

    final selectedOptions = tempSelectedDevices.map((device) {
      return DropdownOption(
        label: device,
        value: device,
      );
    }).toList();

    widget.onDevicesSelected(selectedOptions, isNoneSelected);

    Future.delayed(const Duration(milliseconds: 1), () {
      if (mounted && context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget displayWidget;
    String? displayTooltip = widget.tooltip;

    if (_hasExplicitlySelectedNone) {
      displayWidget = Text(
        _translationService.translate(SharedTranslationKeys.noneOption),
        style: AppTheme.bodySmall.copyWith(
          color: widget.color ?? Theme.of(context).iconTheme.color,
        ),
      );
      displayTooltip = _translationService.translate(SharedTranslationKeys.noneOption);
    } else if (_selectedDevices.isNotEmpty) {
      if (widget.buttonLabel != null) {
        displayWidget = Text(
          widget.buttonLabel!,
          style: AppTheme.bodySmall.copyWith(
            color: widget.color ?? Theme.of(context).iconTheme.color,
          ),
        );
        displayTooltip = _selectedDevices.join(', ');
      } else {
        displayWidget = IconButton(
          icon: Icon(
            widget.icon,
            color: widget.color,
          ),
          iconSize: widget.iconSize ?? AppTheme.iconSizeSmall,
          onPressed: () => _showDeviceSelectionModal(context),
          tooltip: displayTooltip,
        );
        displayTooltip = _selectedDevices.join(', ');
      }
    } else if (widget.buttonLabel != null) {
      displayWidget = Text(
        widget.buttonLabel!,
        style: AppTheme.bodySmall.copyWith(
          color: widget.color ?? Theme.of(context).iconTheme.color,
        ),
      );
    } else {
      displayWidget = IconButton(
        icon: Icon(
          widget.icon,
          color: widget.color,
        ),
        iconSize: widget.iconSize ?? AppTheme.iconSizeSmall,
        onPressed: () => _showDeviceSelectionModal(context),
        tooltip: displayTooltip,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        widget.buttonLabel != null
            ? InkWell(
                onTap: () => _showDeviceSelectionModal(context),
                child: Tooltip(
                  message: displayTooltip ?? '',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: displayWidget,
                  ),
                ),
              )
            : IconButton(
                icon: Icon(
                  widget.icon,
                  color: widget.color ?? Theme.of(context).iconTheme.color,
                ),
                iconSize: widget.iconSize ?? AppTheme.iconSizeSmall,
                onPressed: () => _showDeviceSelectionModal(context),
                tooltip: displayTooltip ?? '',
              ),
      ],
    );
  }
}
