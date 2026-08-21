/// Order is stable — stored as an index in the DB. Append only.
///
/// Only [TripPackingItem]s in [PackingCategory.clothing] ever use values
/// beyond [packed] — every other category is a plain to-pack/packed
/// checkbox (see the design spec, "Clothing lifecycle").
enum PackingItemStatus { toPack, packed, worn, inWash, clean }
