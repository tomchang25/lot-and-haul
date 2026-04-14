# row_data_provider.gd
# Abstract base for overriding price/market-factor display in ItemListPanel.
# Subclass and pass to ItemListPanel.setup() to inject merchant-specific pricing.
# When null (default), rows fall back to entry.price_value_for(ctx) / entry.price_label_for(ctx).
class_name RowDataProvider
extends RefCounted


func price_for(_entry: ItemEntry) -> int:
	push_warning("RowDataProvider.price_for() not overridden")
	return 0


func price_label_for(_entry: ItemEntry) -> String:
	push_warning("RowDataProvider.price_label_for() not overridden")
	return "???"


func price_header() -> String:
	return "Price"


func market_factor_for(_entry: ItemEntry) -> float:
	return 0.0


func market_factor_label_for(_entry: ItemEntry) -> String:
	return "0%"


func market_factor_header() -> String:
	return "Market"
