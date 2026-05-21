import pytest
from calculator import add, subtract, multiply, divide


class TestAdd:
    def test_add_positive_numbers(self):
        assert add(2, 3) == 5
        assert add(10, 20) == 30

    def test_add_negative_numbers(self):
        assert add(-1, -2) == -3
        assert add(-5, -5) == -10

    def test_add_mixed_signs(self):
        assert add(-1, 1) == 0
        assert add(5, -3) == 2

    def test_add_zero(self):
        assert add(0, 0) == 0
        assert add(0, 5) == 5
        assert add(5, 0) == 5

    def test_add_floats(self):
        assert add(0.1, 0.2) == pytest.approx(0.3)
        assert add(1.5, 2.5) == 4.0


class TestSubtract:
    def test_subtract_positive(self):
        assert subtract(5, 3) == 2
        assert subtract(10, 7) == 3

    def test_subtract_negative_result(self):
        assert subtract(3, 5) == -2
        assert subtract(0, 5) == -5

    def test_subtract_zero(self):
        assert subtract(0, 0) == 0
        assert subtract(5, 0) == 5
        assert subtract(0, 5) == -5

    def test_subtract_same_number(self):
        assert subtract(100, 100) == 0
        assert subtract(-5, -5) == 0


class TestMultiply:
    def test_multiply_positive(self):
        assert multiply(3, 4) == 12
        assert multiply(7, 8) == 56

    def test_multiply_by_zero(self):
        assert multiply(0, 100) == 0
        assert multiply(100, 0) == 0
        assert multiply(0, 0) == 0

    def test_multiply_negative(self):
        assert multiply(-2, 3) == -6
        assert multiply(-2, -3) == 6
        assert multiply(2, -3) == -6

    def test_multiply_one(self):
        assert multiply(1, 99) == 99
        assert multiply(99, 1) == 99


class TestDivide:
    def test_divide_positive(self):
        assert divide(10, 2) == 5.0
        assert divide(7, 2) == 3.5

    def test_divide_negative(self):
        assert divide(-6, 3) == -2.0
        assert divide(6, -3) == -2.0
        assert divide(-6, -3) == 2.0

    def test_divide_by_one(self):
        assert divide(99, 1) == 99.0
        assert divide(-5, 1) == -5.0

    def test_divide_by_zero_raises(self):
        with pytest.raises(ValueError, match="Cannot divide by zero"):
            divide(1, 0)
        with pytest.raises(ValueError, match="Cannot divide by zero"):
            divide(0, 0)

    def test_divide_float_result(self):
        assert divide(1, 3) == pytest.approx(1 / 3)
