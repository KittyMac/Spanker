## Spanker

### WARNING: THIS REPOSITORY IS UNDER CONSTRUCTION; COME BACK LATER!

Spanker is a very fast, very memory efficient Swift JSON deserializer useful for embedding into other Swift JSON tools. Spanker is middleware for other Swift JSON tools, providing a hierarchical data structure which provides additional information suitable for said tools.

- Zero Ambiguity  
Spanker does not use ```Any```; the type of every element in the data structure must be easily determinable in a performant manner. This is the main difference between Spanker and JSONSerialization, as the cost of dynamic casting in Swift (ie ```as?```) is high.

- Preserves Ordering  
Dictionaries in Swift are naturally unordered. Spanker, being a tool which other tools rely on, preserves the ordering of the data structure to match how it is in the underlying data.

