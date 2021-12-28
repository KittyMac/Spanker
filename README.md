![](meta/icon.png)

## Spanker

Spanker is used by [Sextant](https://github.com/KittyMac/Sextant) to provide best-in-class JSONPath queries for Swift.

Spanker is a very fast, very memory efficient Swift JSON deserializer useful for embedding into other Swift JSON tools. Spanker is middleware which provides a hierarchical data structure suitable for generically accessing a JSON blob with minimal overhead.

- Zero Ambiguity  
Spanker does not use ```Any```; the type of every element in the data structure must be easily determinable in a performant manner. This is the main difference between Spanker and JSONSerialization, as the cost of dynamic casting in Swift (ie ```as?```) is high.

- Order Preserving  
Dictionaries in Swift are naturally unordered. Spanker, being a tool which other tools rely on, preserves the ordering of the data structure to match how it is in the underlying data.

- Memory Efficiency  
The data structures used by Spanker do not make any copies from the original JSON blob, which reduces the processing overhead dramatically. When you want to have a copy of the data (ie output similar to JSONSerialization) then simply call reify() on the JsonElement. This allows you pay the price of extracting only the specific portion of the JSON hierarchy you care about.

