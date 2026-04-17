"""Extract projection and join order from a parsed UniversalMapping AssignNode."""

from rapt2.treebrd.node import (
    AssignNode,
    Node,
    ProjectNode,
    RelationNode,
)


def _inner(node: AssignNode) -> Node:
    """Peel AssignNode / ProjectNode wrappers to reach the join-or-relation root."""
    current: Node = node
    if isinstance(current, AssignNode):
        current = current.child
    if isinstance(current, ProjectNode):
        current = current.child
    return current


def extract_projection(node: AssignNode) -> list[str]:
    """Return the ProjectNode attribute list wrapping the join tree.

    Raises ValueError if the UniversalMapping is not of the expected
    shape (AssignNode -> ProjectNode -> ...).
    """
    if not isinstance(node, AssignNode):
        raise ValueError(f"Expected AssignNode, got {type(node).__name__}")
    child = node.child
    if not isinstance(child, ProjectNode):
        raise ValueError(
            "UniversalMapping must be wrapped in \\project_{...}; "
            f"got {type(child).__name__}"
        )
    return list(child.attributes.names)


def extract_join_order(node: AssignNode) -> list[str]:
    """Return the left-to-right base-table sequence from a UniversalMapping."""
    if not isinstance(node, AssignNode):
        raise ValueError(f"Expected AssignNode, got {type(node).__name__}")
    return [n.name for n in _inner(node).post_order() if isinstance(n, RelationNode)]
