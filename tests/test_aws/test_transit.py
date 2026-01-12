"""AWS Transit gateway tests."""


def test_transit_created(tf: dict) -> None:
    """Verify transit gateway was created."""
    assert "aws_transit" in tf["outputs"]
    assert tf["outputs"]["aws_transit"]["value"]["gw_name"] is not None
