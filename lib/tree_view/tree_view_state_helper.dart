import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../constants/constants.dart';
import '../helpers/exceptions.dart';
import '../listenable_node/base/i_listenable_node.dart';
import '../node/base/i_node.dart';
import 'tree_node.dart';
import 'tree_view.dart';

abstract class ListState<Tree> {
  void insertItem(int index, {Duration duration = animationDuration});

  void removeItem(
    int index,
    Tree item, {
    Duration duration = animationDuration,
  });
}

class TreeViewStateHelper<Data, Tree extends ITreeNode<Data>> {
  static const tag = "TreeViewStateHelper";

  final Tree tree;
  final AnimatedListStateController<Data, Tree> animatedListStateController;
  final TreeViewExpansionBehaviourController<Data, Tree>
  expansionBehaviourController;
  final bool focusToNewNode;

  late StreamSubscription<NodeAddEvent<INode>> _addedNodesSubscription;
  late StreamSubscription<NodeRemoveEvent<INode>> _removeNodesSubscription;
  StreamSubscription<NodeInsertEvent<INode>>? _insertNodesSubscription;

  TreeViewStateHelper({
    required this.animatedListStateController,
    required this.expansionBehaviourController,
    required this.tree,
    this.focusToNewNode = true,
  }) {
    _addedNodesSubscription = tree.addedNodes.listen(handleAddItemsEvent);
    _removeNodesSubscription = tree.removedNodes.listen(handleRemoveItemsEvent);

    try {
      _insertNodesSubscription = tree.insertedNodes.listen(
        handleInsertItemsEvent,
      );
    } on ActionNotAllowedException catch (_) {}
  }

  @visibleForTesting
  void handleAddItemsEvent(NodeAddEvent<INode> event) {
    for (final node in event.items) {
      if (animatedListStateController.containsKey(node.path)) continue;

      if (node.isRoot || node.parent?.isRoot == true) {
        final root = node.root as Tree;
        if (!root.isExpanded) {
          if (focusToNewNode) {
            expansionBehaviourController.expandNode(root);
          }
        } else {
          animatedListStateController.insertAll(
            animatedListStateController.list.length,
            List.from(event.items),
          );
        }
        if (focusToNewNode) {
          expansionBehaviourController.scrollToLastVisibleChild(root);
        }
      } else {
        final parentIndex = animatedListStateController.list.indexWhere(
          (element) => element.key == node.parent?.key,
        );
        if (parentIndex < 0) continue;

        final parentNode = animatedListStateController.list[parentIndex];

        if (!parentNode.isExpanded) {
          expansionBehaviourController.expandNode(parentNode);
        } else {
          // if the node is expanded, add the items in the flatList and
          // the animatedList
          final insertAtIndex = animatedListStateController.list.lastIndexWhere(
            (element) =>
                element.path.startsWith(parentNode.path) &&
                element.level > parentNode.level,
          );
          if (insertAtIndex < 0) {
            animatedListStateController.insertAll(
              animatedListStateController.length - 1,
              List.from(event.items),
            );
          } else {
            animatedListStateController.insertAll(
              insertAtIndex + 1,
              List.from(event.items),
            );
          }
        }
        if (focusToNewNode) {
          expansionBehaviourController.scrollToLastVisibleChild(parentNode);
        }
      }
    }
  }

  @visibleForTesting
  void handleInsertItemsEvent(NodeInsertEvent<INode> event) {
    if (event.index + event.items.length ==
        (event.items.firstOrNull?.parent?.length ?? 0)) {
      handleAddItemsEvent(NodeAddEvent(event.items));
      return;
    }

    for (final node in event.items) {
      if (animatedListStateController.containsKey(node.path)) continue;
      late Tree parentNode;
      late int parentIndex;

      if (node.isRoot || node.parent?.isRoot == true) {
        parentNode = node.root as Tree;
        parentIndex = 0;
      } else {
        parentIndex = animatedListStateController.list.indexWhere(
          (element) => element.key == node.parent?.key,
        );

        parentNode = animatedListStateController.list[parentIndex];
      }

      if (parentNode.isExpanded) {
        final actualIndex = computeActualIndex(
          parentIndex + event.index,
          parentNode.level,
        );

        animatedListStateController.insertAll(
          actualIndex + 1,
          List.from(event.items),
        );
      } else {
        expansionBehaviourController.expandNode(parentNode);
      }
    }
  }

  @visibleForTesting
  int computeActualIndex(int targetIndex, int parentNodeLevel) {
    int actualIndex = targetIndex;

    for (int i = targetIndex + 1; i < animatedListStateController.length; i++) {
      if (animatedListStateController.list[i].level > parentNodeLevel + 1) {
        actualIndex++;
      } else {
        break;
      }
    }

    return actualIndex;
  }

  @visibleForTesting
  void handleRemoveItemsEvent(NodeRemoveEvent<INode> event) {
    for (final node in event.items) {
      if (!animatedListStateController.containsKey(node.path)) continue;

      //if item is in the root of the list, then remove the item
      if (animatedListStateController.list.any(
        (item) => item.key == node.key,
      )) {
        final index = animatedListStateController.indexOf(node);
        if (index < 0) continue;
        final removedItem = animatedListStateController.removeAt(index);

        if (removedItem.isExpanded) {
          //if the item is expanded, also remove its children
          animatedListStateController.removeAll(
            animatedListStateController.list
                .where(
                  (element) =>
                      !element.isRoot &&
                      (element.path).startsWith(removedItem.path),
                )
                .toList(),
          );
        }
      }
    }
  }

  Future<void> dispose() async {
    Future.wait([
      _addedNodesSubscription.cancel(),
      _removeNodesSubscription.cancel(),
      if (_insertNodesSubscription != null) _insertNodesSubscription!.cancel(),
    ]);
  }
}

class AnimatedListStateController<Data, Tree extends ITreeNode<Data>> {
  final bool showRootNode;
  final ListState<Tree> _listState;

  late final List<Tree> _flatList;
  late final Map<String, Tree> _itemsMap;

  AnimatedListStateController({
    required ListState<Tree> listState,
    required this.showRootNode,
    required Tree tree,
  }) : _listState = listState {
    _flatList = List.from(showRootNode ? [tree] : tree.root.childrenAsList);
    _itemsMap = <String, Tree>{for (final node in _flatList) node.path: node};
  }

  List<Tree> get list => UnmodifiableListView(_flatList);

  int get length => _flatList.length;

  bool containsKey(String key) => _itemsMap.containsKey(key);

  int indexOf(INode item) => _flatList.indexWhere(
    (e) => e.parent?.key == item.parent?.key && e.key == item.key,
  );

  void insert(int index, Tree item) {
    _flatList.insert(index, item);
    _itemsMap[item.path] = item;
    _listState.insertItem(index);
  }

  void insertAll(int index, List<Tree> items) {
    for (int i = 0; i < items.length; i++) {
      insert(index + i, items[i]);
    }
  }

  Tree removeAt(int index) {
    if (index < 0 || index > _flatList.length) {
      throw RangeError.index(index, _flatList);
    }

    _itemsMap.remove(_flatList[index].path);
    final removedItem = _flatList.removeAt(index);
    _listState.removeItem(index, removedItem);

    return removedItem;
  }

  void remove(Tree item) {
    final index = indexOf(item);
    if (index >= 0) removeAt(indexOf(item));
  }

  Future<void> removeAll(List<Tree> items) async {
    await Future.wait(
      items.map((item) {
        item.expansionNotifier.value = false;
        return Future.microtask(() => remove(item));
      }),
    );
  }
}

class TreeViewExpansionBehaviourController<Data, Tree extends ITreeNode<Data>> {
  final AnimatedListStateController<Data, Tree> animatedListStateController;
  final AutoScrollController scrollController;
  final Function(Tree item)? onExpandNode;
  ExpansionBehavior expansionBehavior;

  TreeViewExpansionBehaviourController({
    required this.scrollController,
    required this.expansionBehavior,
    required this.animatedListStateController,
    this.onExpandNode,
  });

  Future scrollToIndex(
    int index, [
    Duration duration = scrollAnimationDuration,
  ]) async => await scrollController.scrollToIndex(
    index,
    preferPosition: AutoScrollPosition.begin,
    duration: duration,
  );

  Future scrollToItem(
    Tree item, [
    Duration duration = scrollAnimationDuration,
  ]) async =>
      await scrollToIndex(animatedListStateController.indexOf(item), duration);

  Future<void> collapseNode(Tree item) async {
    final removeItems = animatedListStateController.list.where(
      (element) =>
          (element.path).startsWith('${item.path}${INode.pathSeperator}'),
    );

    await animatedListStateController.removeAll(removeItems.toList());
    item.expansionNotifier.value = false;
  }

  void expandNode(Tree item) {
    if (item.childrenAsList.isEmpty || item.isExpanded) return;
    onExpandNode?.call(item);

    animatedListStateController.insertAll(
      animatedListStateController.indexOf(item) + 1,
      List.from(item.childrenAsList),
    );

    item.expansionNotifier.value = true;
  }

  Future<void> toggleExpansion(Tree item) async {
    if (item.isExpanded) {
      await collapseNode(item);
    } else {
      expandNode(item);
      await applyExpansionBehavior(item);
    }
  }

  Future<void> applyExpansionBehavior(Tree item) async {
    switch (expansionBehavior) {
      case ExpansionBehavior.none:
        break;
      case ExpansionBehavior.scrollToLastChild:
        await scrollToLastVisibleChild(item);
        break;
      case ExpansionBehavior.snapToTop:
        await snapToTop(item);
        break;
      case ExpansionBehavior.collapseOthers:
        await collapseAllOtherSiblingNodes(item);
        break;
      case ExpansionBehavior.collapseOthersAndSnapToTop:
        await collapseAllOtherSiblingNodes(item);
        await snapToTop(
          item,
          delay: animationDuration + const Duration(milliseconds: 100),
        );
        break;
    }
  }

  Future<void> scrollToLastVisibleChild(INode parent) async {
    final lastChild = parent.childrenAsList.lastOrNull;
    if (lastChild == null) return;

    await Future.delayed(animationDuration);

    //get the index of the last child in the node
    final lastChildIndex = animatedListStateController.indexOf(lastChild);

    //scroll to the last child if it is not visible in the viewPort
    if (!scrollController.isIndexStateInLayoutRange(
      lastChildIndex +
          parent.level.clamp(1, 1000) +
          parent.childrenAsList.length,
    )) {
      await scrollController.scrollToIndex(
        lastChildIndex < animatedListStateController.list.length - 1
            ? lastChildIndex + 1
            : lastChildIndex,
        preferPosition: AutoScrollPosition.end,
      );
    }
  }

  Future<void> snapToTop(
    Tree item, {
    Duration delay = animationDuration,
  }) async {
    await Future.delayed(delay);

    await scrollController.scrollToIndex(
      animatedListStateController.indexOf(item),
      preferPosition: AutoScrollPosition.begin,
    );
  }

  Future<void> collapseAllOtherSiblingNodes(Tree node) async {
    await Future.wait(
      (node.parent?.childrenAsList ?? []).map((siblingNode) {
        if (siblingNode.key != node.key &&
            (siblingNode as ITreeNode).isExpanded) {
          return collapseNode(siblingNode as Tree);
        }
        return Future.value();
      }),
    );
  }
}

class LastChildCacheManager<Data, Tree extends ITreeNode<Data>> {
  final Tree tree;
  final Map<INode, bool> _lastChildMap;

  late StreamSubscription<NodeAddEvent<INode>> _addedNodesSubscription;
  late StreamSubscription<NodeRemoveEvent<INode>> _removeNodesSubscription;
  StreamSubscription<NodeInsertEvent<INode>>? _insertNodesSubscription;

  LastChildCacheManager(this.tree) : _lastChildMap = <INode, bool>{} {
    {
      _addedNodesSubscription = tree.addedNodes.listen(handleItemChangeEvent);
      _removeNodesSubscription = tree.removedNodes.listen(
        handleItemChangeEvent,
      );
      try {
        _insertNodesSubscription = tree.insertedNodes.listen(
          handleItemChangeEvent,
        );
      } on ActionNotAllowedException catch (_) {}
    }

    indexChildren(tree);
  }

  bool isLastChild(INode node) => _lastChildMap[node] != null;

  void indexChildren(INode node) {
    if (node.length <= 0) return;
    _lastChildMap[node.childrenAsList[node.length - 1]] = true;
  }

  void updateChildrenIndices(INode node) {
    clearChildrenIndex(node);
    indexChildren(node);
  }

  void clearChildrenIndex(INode node) {
    for (final childNode in node.childrenAsList) {
      _lastChildMap.remove(childNode);
    }
  }

  @visibleForTesting
  void handleItemChangeEvent(NodeEvent<INode> event) {
    final parent = event.items.firstOrNull?.parent;
    if (parent != null) updateChildrenIndices(parent);
  }

  Future<void> dispose() async {
    Future.wait([
      _addedNodesSubscription.cancel(),
      _removeNodesSubscription.cancel(),
      if (_insertNodesSubscription != null) _insertNodesSubscription!.cancel(),
    ]);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LastChildCacheManager &&
          runtimeType == other.runtimeType &&
          tree == other.tree &&
          _lastChildMap == other._lastChildMap;

  @override
  int get hashCode => tree.hashCode ^ _lastChildMap.hashCode;
}
