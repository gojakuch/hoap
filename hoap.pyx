# level:         Python/Hy         Cython              C API
#                 Hopper---------->HopUnit---------->PyObject
#               [PyObject]       [C-struct]         [PyObject]
# processes:    Using      Allocation&Processing    Allocation

# Hoap (Heap Object Allocator and Processor) allows a Hy or Python programmer (a
# high-level, interpreted, dynamically typed language coder) to work with memory and do it safely.
# This, in turn, gives the porgrammer power to create complex structures,
# such as intertwined lists (lists of Hoppers, Hoap's safe pointers), and use the power of pointers to create
# functions with side effects on their arguments. Such simulation (or rather implementation, as it is indeed
# based on pointers) is much faster and clearer than one can be built using pure Python and its lists as mutable
# objects.

#  Atell Krasnopolski, 2020



from cpython.ref cimport PyObject, Py_XINCREF, Py_XDECREF
from libc.stdlib cimport malloc
from libc.stdlib cimport free as cfree
cdef extern from *:
    ctypedef Py_ssize_t Py_intptr_t

ctypedef short status; # Hoap's low-level functions return a short integer as their status, while actual output is always provided in a form of pointer-typed argument
DEF HOP_STAT_ERROR = -1
DEF HOP_STAT_OK = 0
DEF HOP_STAT_DONE = 1
DEF HOP_STAT_EXITED = 2



## shows whether Hoap Memory System is stable or not
# Once the system has become unstable, it remains such untill the program exits.
# When the HMS is unstable, segmentation faults may occure.
cdef bint HMSYS_STABLE_STATUS = True;

def is_hms_stable():
  """Returns None if Hoap Memory System is not stable or 1 if it is"""
  if HMSYS_STABLE_STATUS:
    return 1
  else:
    return None

cdef void HMS_SetUnstable():
  global HMSYS_STABLE_STATUS
  HMSYS_STABLE_STATUS = False



## Hoap errors
cdef class NullhopError(Exception):
    """Trying to dereference a Hopper that points to nullhop"""
    pass



## HopUnit implementation & functions (all functions for HopUnits start with HU_ and take a pointer to a HopUnit as 1st arg.)
cdef struct HopUnit:
  PyObject* objptr # note that HopUnit cannot actually point to NULL. When we allocate a new HopUnit with alloc(), None is assigned to this unit
  Py_ssize_t refcnt

cdef HopUnit* HU_Factory():
  cdef HopUnit* ptr = <HopUnit*> malloc(sizeof(HopUnit))
  if not ptr:
    raise MemoryError()
  cdef HopUnit _struct
  ptr[0] = _struct
  ptr.objptr = NULL # temporary NULL value
  ptr.refcnt = 1
  return ptr

cdef HopUnit* HU_CollFactory(Py_ssize_t size): # collection factory
  cdef HopUnit* ptr = <HopUnit*> malloc(size*sizeof(HopUnit))
  if not ptr:
    raise MemoryError()
  cdef HopUnit _struct
  _struct.objptr = NULL
  _struct.refcnt = 1
  for i in range(size):
    ptr[i] = _struct
  return ptr

cdef status HU_XDecRef(HopUnit* u): # decrement reference count. returns HOP_STAT_DONE if HU gets disposed
  if u:
    if u.refcnt == 1:
      Py_XDECREF(u.objptr)
      cfree(u);
      return HOP_STAT_DONE;
    u.refcnt -= 1
    return HOP_STAT_OK;
  return HOP_STAT_EXITED;

cdef status HU_XIncRef(HopUnit* u): # increment reference count
  if u:
    u.refcnt += 1
    return HOP_STAT_DONE;
  return HOP_STAT_EXITED;

cdef status HU_XAssign(HopUnit* u, PyObject* val):
  if u:
    Py_XDECREF(u.objptr)
    u.objptr = val
    Py_XINCREF(u.objptr)
    return HOP_STAT_DONE;
  return HOP_STAT_EXITED;



## definition of nullhop - a unit that points to NULL. A Hopper pointing to it is considered empty. Hopper cannot point to NULL themselves, as they are upper-level pointers
cdef HopUnit* nullhop = HU_Factory();
if not nullhop:
  raise MemoryError()



## Hopper implementation (as a class)
cdef class Hopper:
  """A pointer-like class that can be used from Hy or Python level"""
  cdef HopUnit* ptr
  cdef Py_ssize_t _size

  def __cinit__(self):
    self.ptr = nullhop
    self._size = 1
    HU_XIncRef(nullhop)

  def __dealloc__(self):
    HU_XDecRef(self.ptr)

  @property
  def val(self):
    if self.is_null():
      raise NullhopError()
    return <object>(self.ptr.objptr)

  @val.setter
  def val(self, val):
    if self.is_null():
      HU_XDecRef(self.ptr)
      self.ptr = HU_Factory();
    HU_XAssign(self.ptr, <PyObject*>val)

  @property
  def unit_adress(self):
    return <Py_intptr_t>self.ptr

  def __getitem__(self, key):
    if self.is_null():
      raise NullhopError()
    if key >= self._size or key < 0:
      raise IndexError()
    return <object>(self.ptr[key].objptr)

  def __setitem__(self, key, val):
    if self.is_null():
      raise NullhopError()
    if key >= self._size or key < 0:
      raise IndexError()
    HU_XAssign(&(self.ptr[key]), <PyObject*>val)

  def __eq__(self, other):
    if type(other) != type(self):
      raise TypeError()
    if self.unit_adress == other.unit_adress:
      return 1
    return None

  def __ne__(self, other):
    if self.__eq__(other):
      return None
    return 1

  def __hash__(self):
    return hash(<Py_intptr_t>self.ptr)

  def __repr__(self):
    if self.is_null():
      return "Nullhop"
    if self._size == 1:
      return "Hopper to "+hex(self.unit_adress)+" with "+str(self.val)
    return "Hopper to LowCollection at "+hex(self.unit_adress)

  def __str__(self):
    if self.is_null():
      return "Nullhop"
    if self._size == 1:
      return "Hopper to "+repr(self.val)
    return "Hopper to LowColl"+repr([self.__getitem__(i) for i in range(self._size)])

  def __len__(self):
    return self.size

  def __contains__(self, arg):
    for i in range(self._size):
      if <object>(self.ptr[i].objptr) == arg:
        return 1
    return 0

  cpdef object is_null(self):
    """Checks whether the pointer is null. returns None if not to be compatible with Lisp if statement from Hy"""
    if self.ptr != nullhop:
      return None
    return 1

  cpdef object is_lowcoll(self):
    """Checks whether a hopper is a low-level collection or not"""
    if self._size == 1:
      return None
    return 1



## Nullhop detectable from Python/Hy
Nullhop = Hopper()

cdef void NULL_UPD(): # update Nullhop
  global Nullhop
  Nullhop = Hopper()



## Outer operations for Python/Hy level
cpdef Hopper alloc(object val=None):
  """Allocates a new HopUnit with a given value or None, returns a Hopper to it"""
  NULL_UPD()
  cdef Hopper h = Hopper()
  h.val = val
  return h

cpdef Hopper calloc(object arg):
  """Allocates a new collection of the given size or with given values, returns a Hopper to it"""
  NULL_UPD()
  cdef Py_ssize_t size
  cdef Hopper h = Hopper()
  HU_XDecRef(h.ptr)
  if isinstance(arg, int):
    size = arg
    h.ptr = HU_CollFactory(size)
    for i in range(size):
      HU_XAssign(&(h.ptr[i]), <PyObject*>None)
  else:
    size = len(arg)
    h.ptr = HU_CollFactory(size)
    for i in range(size):
      HU_XAssign(&(h.ptr[i]), <PyObject*>arg[i])
  h._size = size
  return h

cpdef Hopper bound(Hopper h):
  """Returns a new Hopper bound to the given one (they point to the same value)"""
  NULL_UPD()
  cdef Hopper new = Hopper()
  HU_XDecRef(new.ptr)
  new.ptr = h.ptr
  HU_XIncRef(new.ptr)
  new._size = h._size
  return new;

cpdef object deref(Hopper h):
  """Dereferences a Hopper, returns a Python object. Same as Hopper.val"""
  return h.val

cpdef void sethv(Hopper h, object val):
  """Sets Hopper value (actual value when dereferencing) to a new given one"""
  h.val = val

cpdef void swapval(Hopper h1, Hopper h2):
  """Swaps values (HopUnit.objptr) of two hoppers (values, not just their names)"""
  cdef PyObject* tmp = h1.ptr.objptr
  h1.ptr.objptr = h2.ptr.objptr
  h2.ptr.objptr = tmp

cpdef list lowcoll_to_list(Hopper h):
  """Converts a low-level collection into a Python's standard list"""
  return [<object>(h.ptr[i].objptr) for i in range(h._size)]



## Unsafe operations, not recommended
cpdef Hopper hopper_from_adress(Py_intptr_t h):
  """Makes a Hopper that points to a specific location (should be HopUnit*) given as an integer. Sets HMS status to unstable"""
  HMS_SetUnstable()
  NULL_UPD()
  cdef Hopper new = Hopper()
  HU_XDecRef(new.ptr)
  new.ptr = <HopUnit*>h
  HU_XIncRef(new.ptr)
  return new;

#cpdef void free(Hopper h):
#  """Frees memory allocated for a HopUnit by destroying it. Sets HMS status to unstable. Unusable"""
#  HMS_SetUnstable()
#  Py_XDECREF(h.ptr.objptr)
#  cfree(h.ptr)
