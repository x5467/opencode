"""Legacy order management module. Refactor target: split into
models.py, repository.py, service.py with imports corrected."""

from __future__ import annotations

import json
import sqlite3
import threading
from dataclasses import dataclass, field
from datetime import datetime, timezone
from decimal import Decimal
from enum import Enum
from typing import Iterable, Optional


# ---------------------------------------------------------------------------
# Section 1: domain models  (target: models.py)
# ---------------------------------------------------------------------------

class OrderStatus(str, Enum):
    PENDING = "pending"
    PAID = "paid"
    SHIPPED = "shipped"
    DELIVERED = "delivered"
    CANCELLED = "cancelled"


class PaymentMethod(str, Enum):
    CARD = "card"
    TRANSFER = "transfer"
    CREDIT = "credit"


VALID_TRANSITIONS = {
    OrderStatus.PENDING: {OrderStatus.PAID, OrderStatus.CANCELLED},
    OrderStatus.PAID: {OrderStatus.SHIPPED, OrderStatus.CANCELLED},
    OrderStatus.SHIPPED: {OrderStatus.DELIVERED},
    OrderStatus.DELIVERED: set(),
    OrderStatus.CANCELLED: set(),
}


class DomainError(Exception):
    """Base error for order domain violations."""


class InvalidTransition(DomainError):
    def __init__(self, current: OrderStatus, target: OrderStatus) -> None:
        super().__init__(f"cannot move order from {current.value} to {target.value}")
        self.current = current
        self.target = target


class InsufficientStock(DomainError):
    def __init__(self, sku: str, requested: int, available: int) -> None:
        super().__init__(f"sku {sku}: requested {requested}, available {available}")
        self.sku = sku
        self.requested = requested
        self.available = available


@dataclass
class Product:
    sku: str
    name: str
    unit_price: Decimal
    stock: int = 0

    def reserve(self, quantity: int) -> None:
        if quantity <= 0:
            raise DomainError("quantity must be positive")
        if quantity > self.stock:
            raise InsufficientStock(self.sku, quantity, self.stock)
        self.stock -= quantity

    def restock(self, quantity: int) -> None:
        if quantity <= 0:
            raise DomainError("restock quantity must be positive")
        self.stock += quantity


@dataclass
class OrderLine:
    sku: str
    quantity: int
    unit_price: Decimal

    @property
    def subtotal(self) -> Decimal:
        return self.unit_price * self.quantity

    def to_dict(self) -> dict:
        return {
            "sku": self.sku,
            "quantity": self.quantity,
            "unit_price": str(self.unit_price),
        }

    @classmethod
    def from_dict(cls, raw: dict) -> "OrderLine":
        return cls(
            sku=raw["sku"],
            quantity=int(raw["quantity"]),
            unit_price=Decimal(raw["unit_price"]),
        )


@dataclass
class Order:
    order_id: str
    customer_id: str
    lines: list[OrderLine] = field(default_factory=list)
    status: OrderStatus = OrderStatus.PENDING
    payment_method: Optional[PaymentMethod] = None
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))

    @property
    def total(self) -> Decimal:
        return sum((line.subtotal for line in self.lines), Decimal("0"))

    def add_line(self, line: OrderLine) -> None:
        if self.status is not OrderStatus.PENDING:
            raise DomainError("lines can only be added to pending orders")
        for existing in self.lines:
            if existing.sku == line.sku:
                existing.quantity += line.quantity
                return
        self.lines.append(line)

    def transition(self, target: OrderStatus) -> None:
        if target not in VALID_TRANSITIONS[self.status]:
            raise InvalidTransition(self.status, target)
        self.status = target

    def to_dict(self) -> dict:
        return {
            "order_id": self.order_id,
            "customer_id": self.customer_id,
            "lines": [line.to_dict() for line in self.lines],
            "status": self.status.value,
            "payment_method": self.payment_method.value if self.payment_method else None,
            "created_at": self.created_at.isoformat(),
        }

    @classmethod
    def from_dict(cls, raw: dict) -> "Order":
        order = cls(
            order_id=raw["order_id"],
            customer_id=raw["customer_id"],
            lines=[OrderLine.from_dict(l) for l in raw.get("lines", [])],
            status=OrderStatus(raw.get("status", "pending")),
            created_at=datetime.fromisoformat(raw["created_at"]),
        )
        if raw.get("payment_method"):
            order.payment_method = PaymentMethod(raw["payment_method"])
        return order


# ---------------------------------------------------------------------------
# Section 2: persistence  (target: repository.py)
# ---------------------------------------------------------------------------

class OrderRepository:
    """SQLite-backed store. Orders are serialized as JSON documents."""

    def __init__(self, path: str = ":memory:") -> None:
        self._conn = sqlite3.connect(path, check_same_thread=False)
        self._lock = threading.Lock()
        self._conn.execute(
            "CREATE TABLE IF NOT EXISTS orders ("
            " order_id TEXT PRIMARY KEY,"
            " customer_id TEXT NOT NULL,"
            " status TEXT NOT NULL,"
            " body TEXT NOT NULL)"
        )
        self._conn.execute(
            "CREATE TABLE IF NOT EXISTS products ("
            " sku TEXT PRIMARY KEY,"
            " name TEXT NOT NULL,"
            " unit_price TEXT NOT NULL,"
            " stock INTEGER NOT NULL)"
        )
        self._conn.commit()

    def save_order(self, order: Order) -> None:
        with self._lock:
            self._conn.execute(
                "INSERT INTO orders (order_id, customer_id, status, body)"
                " VALUES (?, ?, ?, ?)"
                " ON CONFLICT(order_id) DO UPDATE SET"
                " status = excluded.status, body = excluded.body",
                (order.order_id, order.customer_id, order.status.value,
                 json.dumps(order.to_dict())),
            )
            self._conn.commit()

    def get_order(self, order_id: str) -> Optional[Order]:
        row = self._conn.execute(
            "SELECT body FROM orders WHERE order_id = ?", (order_id,)
        ).fetchone()
        if row is None:
            return None
        return Order.from_dict(json.loads(row[0]))

    def orders_by_status(self, status: OrderStatus) -> list[Order]:
        rows = self._conn.execute(
            "SELECT body FROM orders WHERE status = ?", (status.value,)
        ).fetchall()
        return [Order.from_dict(json.loads(r[0])) for r in rows]

    def save_product(self, product: Product) -> None:
        with self._lock:
            self._conn.execute(
                "INSERT INTO products (sku, name, unit_price, stock)"
                " VALUES (?, ?, ?, ?)"
                " ON CONFLICT(sku) DO UPDATE SET"
                " name = excluded.name, unit_price = excluded.unit_price,"
                " stock = excluded.stock",
                (product.sku, product.name, str(product.unit_price), product.stock),
            )
            self._conn.commit()

    def get_product(self, sku: str) -> Optional[Product]:
        row = self._conn.execute(
            "SELECT sku, name, unit_price, stock FROM products WHERE sku = ?",
            (sku,),
        ).fetchone()
        if row is None:
            return None
        return Product(sku=row[0], name=row[1], unit_price=Decimal(row[2]), stock=row[3])

    def all_products(self) -> list[Product]:
        rows = self._conn.execute(
            "SELECT sku, name, unit_price, stock FROM products ORDER BY sku"
        ).fetchall()
        return [Product(r[0], r[1], Decimal(r[2]), r[3]) for r in rows]

    def close(self) -> None:
        self._conn.close()


# ---------------------------------------------------------------------------
# Section 3: service layer  (target: service.py)
# ---------------------------------------------------------------------------

class OrderService:
    def __init__(self, repo: OrderRepository) -> None:
        self.repo = repo
        self._counter = 0
        self._counter_lock = threading.Lock()

    def _next_id(self) -> str:
        with self._counter_lock:
            self._counter += 1
            return f"ORD-{self._counter:06d}"

    def create_order(self, customer_id: str,
                     items: Iterable[tuple[str, int]]) -> Order:
        order = Order(order_id=self._next_id(), customer_id=customer_id)
        for sku, quantity in items:
            product = self.repo.get_product(sku)
            if product is None:
                raise DomainError(f"unknown sku: {sku}")
            product.reserve(quantity)
            self.repo.save_product(product)
            order.add_line(OrderLine(sku, quantity, product.unit_price))
        self.repo.save_order(order)
        return order

    def pay(self, order_id: str, method: PaymentMethod) -> Order:
        order = self._require(order_id)
        order.transition(OrderStatus.PAID)
        order.payment_method = method
        self.repo.save_order(order)
        return order

    def ship(self, order_id: str) -> Order:
        order = self._require(order_id)
        order.transition(OrderStatus.SHIPPED)
        self.repo.save_order(order)
        return order

    def cancel(self, order_id: str) -> Order:
        order = self._require(order_id)
        order.transition(OrderStatus.CANCELLED)
        for line in order.lines:
            product = self.repo.get_product(line.sku)
            if product is not None:
                product.restock(line.quantity)
                self.repo.save_product(product)
        self.repo.save_order(order)
        return order

    def revenue_report(self) -> dict:
        delivered = self.repo.orders_by_status(OrderStatus.DELIVERED)
        paid = self.repo.orders_by_status(OrderStatus.PAID)
        shipped = self.repo.orders_by_status(OrderStatus.SHIPPED)
        realized = sum((o.total for o in delivered), Decimal("0"))
        committed = sum((o.total for o in paid + shipped), Decimal("0"))
        return {
            "realized": str(realized),
            "committed": str(committed),
            "delivered_orders": len(delivered),
            "open_orders": len(paid) + len(shipped),
        }

    def _require(self, order_id: str) -> Order:
        order = self.repo.get_order(order_id)
        if order is None:
            raise DomainError(f"no such order: {order_id}")
        return order
