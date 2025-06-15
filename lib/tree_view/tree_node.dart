import 'package:flutter/foundation.dart';

import '../listenable_node/base/i_listenable_node.dart';
import '../listenable_node/indexed_listenable_node.dart';
import '../listenable_node/listenable_node.dart';
import '../node/base/i_node.dart';
import 'tree_view.dart';

/// Base class that allows a data of type [T] to be wrapped in a [ListenableNode]
mixin ITreeNode<T> on IListenableNode implements ValueListenable<INode> {
  /// ValueNotifier for node expansion/collapse
  late final ValueNotifier<bool> expansionNotifier = ValueNotifier(false);

  /// [ValueNotifier] for data [T] that can be listened for data changes;
  ValueNotifier<T?> get listenableData;

  /// Shows whether the node is expanded or not
  bool get isExpanded => expansionNotifier.value;

  /// The data value of [T] wrapped in the [ITreeNode]
  T? get data => listenableData.value;

  /// The setter for data value [T] wrapped in the Node.
  /// It will notify [listenableData] whenever the value is set.
  set data(T? value) {
    listenableData.value = value;
  }
}

/// A [TreeNode] that can be used with the [TreeView].
///
/// To use your own custom data with [TreeView], wrap your model [T] in [TreeNode]
/// like this:
/// ```dart
///   class YourCustomNode extends TreeNode<CustomClass> {
///   ...
///   }
/// ```
class TreeNode<T> extends ListenableNode with ITreeNode<T> {
  /// A [TreeNode] constructor that can be used with the [TreeView].
  /// Any data of type [T] can be wrapped with [TreeNode]
  TreeNode({T? data, super.key, super.parent})
      : listenableData = ValueNotifier(data);

  /// Factory constructor to be used only for root [TreeNode]
  factory TreeNode.root({T? data}) => TreeNode(key: INode.rootKey, data: data);

  /// [ValueNotifier] for data [T] that can be listened for data changes;
  @override
  final ValueNotifier<T?> listenableData;
}

/// A [IndexedTreeNode] that can be used with the [IndexedTreeView].
///
/// To use your own custom data with [IndexedTreeView], wrap your model [T] in [IndexedTreeNode]
/// like this:
/// ```dart
///   class YourCustomNode extends IndexedTreeView<CustomClass> {
///   ...
///   }
/// ```
class IndexedTreeNode<T> extends IndexedListenableNode with ITreeNode<T> {
  /// A [IndexedTreeNode] constructor that can be used with the [IndexedTreeView].
  /// Any data of type [T] can be wrapped with [IndexedTreeView]
  IndexedTreeNode({T? data, super.key, super.parent})
      : listenableData = ValueNotifier(data);

  /// Factory constructor to be used only for root [IndexedTreeNode]
  factory IndexedTreeNode.root({T? data}) =>
      IndexedTreeNode(key: INode.rootKey, data: data);

  /// [ValueNotifier] for data [T] that can be listened for data changes;
  @override
  final ValueNotifier<T?> listenableData;
}
