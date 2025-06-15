import 'package:flutter/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../node/base/i_node.dart';
import '../tree_node.dart';
import '../tree_view.dart';
import '../tree_view_state_helper.dart';
import 'expansion_indicator.dart';
import 'indent.dart';

class ExpandableNodeItem<Data, Tree extends ITreeNode<Data>>
    extends StatelessWidget {
  final TreeNodeWidgetBuilder<Tree> builder;
  final AutoScrollController scrollController;
  final Tree node;
  final Animation<double> animation;
  final Indentation indentation;
  final ExpansionIndicatorBuilder<Data>? expansionIndicatorBuilder;
  final bool remove;
  final int? index;
  final ValueSetter<Tree>? onItemTap;
  final ValueSetter<Tree> onToggleExpansion;
  final bool showRootNode;
  final LastChildCacheManager lastChildCacheManager;

  static Widget insertedNode<Data, Tree extends ITreeNode<Data>>({
    required int index,
    required Tree node,
    required TreeNodeWidgetBuilder<Tree> builder,
    required AutoScrollController scrollController,
    required Animation<double> animation,
    required ExpansionIndicatorBuilder<Data>? expansionIndicator,
    required ValueSetter<Tree>? onItemTap,
    required ValueSetter<Tree> onToggleExpansion,
    required bool showRootNode,
    required Indentation indentation,
    required LastChildCacheManager lastChildCacheManager,
  }) {
    return ValueListenableBuilder<INode>(
      key: ValueKey(node.key + index.toString()),
      valueListenable: node,
      builder: (context, treeNode, _) => ValueListenableBuilder(
        valueListenable: (treeNode as Tree).listenableData,
        builder: (context, data, _) => ExpandableNodeItem<Data, Tree>(
          builder: builder,
          scrollController: scrollController,
          node: node,
          index: index,
          animation: animation,
          indentation: indentation,
          expansionIndicatorBuilder: expansionIndicator,
          onToggleExpansion: onToggleExpansion,
          onItemTap: onItemTap,
          showRootNode: showRootNode,
          lastChildCacheManager: lastChildCacheManager,
        ),
      ),
    );
  }

  static Widget removedNode<Data, Tree extends ITreeNode<Data>>({
    required Tree node,
    required TreeNodeWidgetBuilder<Tree> builder,
    required AutoScrollController scrollController,
    required Animation<double> animation,
    required ExpansionIndicatorBuilder<Data>? expansionIndicator,
    required ValueSetter<Tree>? onItemTap,
    required ValueSetter<Tree> onToggleExpansion,
    required bool showRootNode,
    required Indentation indentation,
    required LastChildCacheManager lastChildCacheManager,
  }) {
    return ExpandableNodeItem<Data, Tree>(
      key: ValueKey(node.key),
      builder: builder,
      scrollController: scrollController,
      node: node,
      remove: true,
      animation: animation,
      indentation: indentation,
      expansionIndicatorBuilder: expansionIndicator,
      onItemTap: onItemTap,
      onToggleExpansion: onToggleExpansion,
      showRootNode: showRootNode,
      lastChildCacheManager: lastChildCacheManager,
    );
  }

  const ExpandableNodeItem({
    super.key,
    required this.builder,
    required this.scrollController,
    required this.node,
    required this.animation,
    required this.onToggleExpansion,
    this.index,
    this.remove = false,
    this.expansionIndicatorBuilder,
    this.onItemTap,
    required this.showRootNode,
    required this.indentation,
    required this.lastChildCacheManager,
  });

  @override
  Widget build(BuildContext context) {
    final itemContainer = ExpandableNodeContainer<Data, Tree>(
      key: ValueKey("container#$key"),
      animation: animation,
      node: node,
      indentation: indentation,
      minLevelToIndent: showRootNode ? 0 : 1,
      lastChildCacheManager: lastChildCacheManager,
      expansionIndicator: node.childrenAsList.isEmpty
          ? null
          : expansionIndicatorBuilder?.call(context, node),
      onTap: remove
          ? null
          : (item) {
              onToggleExpansion(item);
              if (onItemTap != null) onItemTap!(item);
            },
      child: builder(context, node),
    );

    if (index == null || remove) return itemContainer;

    return AutoScrollTag(
      key: ValueKey("tag#${node.key}"),
      controller: scrollController,
      index: index!,
      child: itemContainer,
    );
  }
}

class ExpandableNodeContainer<Data, Tree extends ITreeNode<Data>>
    extends StatelessWidget {
  final Animation<double> animation;
  final ValueSetter<Tree>? onTap;
  final Tree node;
  final ExpansionIndicator? expansionIndicator;
  final Indentation indentation;
  final Widget child;
  final int minLevelToIndent;
  final LastChildCacheManager lastChildCacheManager;

  const ExpandableNodeContainer({
    super.key,
    required this.animation,
    required this.onTap,
    required this.child,
    required this.node,
    required this.indentation,
    required this.minLevelToIndent,
    required this.lastChildCacheManager,
    this.expansionIndicator,
  });

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      axis: Axis.vertical,
      sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap == null ? null : () => onTap!(node),
        child: Indent(
          indentation: indentation,
          node: node,
          minLevelToIndent: minLevelToIndent,
          lastChildCacheManager: lastChildCacheManager,
          child: expansionIndicator == null
              ? child
              : PositionedExpansionIndicator(
                  expansionIndicator: expansionIndicator!,
                  child: child,
                ),
        ),
      ),
    );
  }
}
