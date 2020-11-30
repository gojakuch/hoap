![logo](https://github.com/gojakuch/hoap/blob/main/logo.png)

# Hoap - Use Pointers from Python or Hy
Hoap is a module that gives you access to pointers and advanced memory management in Python.

Hoap (Heap Object Allocator and Processor) allows a Hy or Python programmer (a high-level language coder) to work with memory and do it safely. This, in turn, gives the programmer power to create complex structures, such as intertwined lists (lists of Hoppers, Hoap's safe pointers), and use the power of pointers to create functions with side effects on their arguments. Such simulation (or rather implementation, as it is indeed based on pointers) is much faster and clearer than one can be built using pure Python and its lists as mutable objects.

## Hoap Memory System
When working in Python or Hy, we only work with Python Objects (PyObjects), so how can we access pointers? Easily, if they are wrapped in Python extension types. Hopper is a class that is used to work with pointers in Hoap:
```
import hoap
h = Hopper() # this will create an empty Hopper that equals Nullhop
```
Hoppers, however, cannot point directly to PyObjects, as Python allocates PyObjects dynamically and, in most cases, they are not changed throughout their lives (most of Python's types are immutable). For this reason, a Hopper always points to a C structure that is not accessible from Python code directly. The structure itself points to a PyObject and may change its location and value when needed. Such structures are named HopUnits. This architecture of Hoap Memory System allows us to create pointer-like structures that may point to the same exact value forever from Python code.
```
# level:         Python/Hy         Cython             C API
#                 Hopper---------->HopUnit---------->PyObject
#               [PyObject]       [C-struct]         [PyObject]
```
Important points:
1) Hopper clean memory after their "death" so there is no need to perform deallocation manually. The further code is completely safe:
```
while True:
  h = hoap.alloc("A long long long long long long string")
```
2) Hoppers, on C[ython] level, may point not to a single HopUnit, but to an array of those. Such a structure should be named LowColl (or low-level collection) and is fully supported bu Hoap module.

## How to install
On Linux, just go to downloaded `hoap` directory and run:
```
$ sudo python3 setup.py install
```
On Windows, generally, you should do the same thing.

## Functions and keywords
Here are signatures and descriptions of the functions Hoap provides for working with memory:
```
alloc(value=None) -> Hopper
  # Allocates a new HopUnit with a given value or None, returns a Hopper to it
calloc(arg) -> Hopper
  # Allocates a new collection of the given size or with given values, returns a Hopper to it
bound(hopper) -> Hopper
  # Returns a new Hopper bound to the given one (they point to the same value, changing one would impact another)
deref(hopper) -> object
  # Dereferences a Hopper, returns a Python object. Same as Hopper.val
sethv(hopper, val)
  # Sets Hopper value (actual value when dereferencing) to a new given one
swapval(hopper1, hopper2)
  # Swaps values of two hoppers (values, not just their names, all the pointers bound to these are affected)
lowcoll_to_list(hopper) -> list
  # Converts a low-level collection into a Python's standard list
is_hms_stable() -> None or 1
  # Returns None if Hoap Memory System is not stable or 1 if it is
```
There are also several unsafe methods that change HMS status to unsafe (which may lead to segmentation faults), these are, therefore, strongly not recommended:
```
hopper_from_adress(int_mem_adress) -> Hopper
  # Makes a Hopper that points to a specific location (should be HopUnit*) given as an integer. Sets HMS status to unstable
```
Keywords:
```
# Nullhop. These two lines are pretty much identical. By default, Nullhop updates its value regularly, but do not assign anything to it or change its value, as it may cause some errors.
h = Nullhop
h = Hopper()
```
## Hopper class
Each Hopper is a safe and clever pointer, but it also has a specific readonly field containing its length. It is 1 if the Hopper points to a single value, or it can be any positive integer representing length of the LowColl connected to that Hopper.
#### Special methods:
```
self.__len__()                      # returns hopper._size
self.__contains__(x)                # returns whether x is in the LowColl
self.__getitem__(inx)               # returns an object from LowColl indexed with inx
self.__setitem__(inx, val)          # sets an object from LowColl indexed with inx
self.__eq__(h)                      # returns 1 if self points to the same location as h. Otherwise, returns None
self.__ne__(h)                      # returns the opposite of self.__eq__(h)
self.__hash__()
self.__repr__()
self.__str__()
```
#### Methods and properties:
```
self.is_null()                      # tells whether self points to Nullhop or not
self.is_lowcoll()                   # checks whether a Hopper is a low-level collection or not
self.val                            # a property that CAN be modified; dereferences a Hopper is same as self.__getitem__(0)
self.unit_adress                    # a property that returns an integer adress of what a Hopper points to
```

## Notes on mutable structures
When "allocating", HMS doesn't copy the object given to `alloc()` as an argument, it creates a HopUnit that points to this exact object and returns a Hopper pointing to that exact HopUnit. This works fine and understandable with immutable structures even for those not familiar with Python's internal architecture. But when pointing Hoppers to mutable structures, this leads to an unexpected result:
```
import hoap

a = [0, 0, 0]
h0 = hoap.alloc(a)
h1 = hoap.alloc(a)

h0.val[0] = "AFFECTED FROM h0"
h1.val[1] = "AFFECTED FROM h1"
print(a)      # -> ['AFFECTED FROM h0', 'AFFECTED FROM h1', 0]
print(h0)     # -> Hopper to ['AFFECTED FROM h0', 'AFFECTED FROM h1', 0]
print(h1)     # -> Hopper to ['AFFECTED FROM h0', 'AFFECTED FROM h1', 0]
```
However, `h0` and `h1` are different and unequal pointers, as they point to the same object only on Python level, but in HMS they are not bound.
```
print(h0==h1) # -> None
```








by Atell Krasnopolski
