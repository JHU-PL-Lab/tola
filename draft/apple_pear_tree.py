from abc import ABC
from dataclasses import dataclass

@dataclass(kw_only=True)
class Tree(ABC):
  tag : str


# `PearTree`` is a binary-node `PearFork` or leaf-node `Pear`
@dataclass(kw_only=True)
class PearTree(Tree):
  tag : str
    
@dataclass(kw_only=True)
class PearFork(PearTree):
  e1 : PearTree
  e2 : PearTree
  tag : str = "PearFork"

  def __str__(self):
    return "[%s: %s, %s]" % (self.tag, self.e1, self.e2)
  
@dataclass(kw_only=True)
class Pear(PearTree):
  tag : str = "Pear"
  
  def __str__(self):
    return "Pear"

# `AppleTree`` is a unary-node `AppleFork` or leaf-node `Apple`

@dataclass(kw_only=True)
class AppleTree(Tree):
  tag : str
    
@dataclass(kw_only=True)
class AppleFork(AppleTree):
  e : AppleTree
  tag : str = "AppleFork"

  def __str__(self):
    return "[%s: %s]" % (self.tag, self.e)
  
@dataclass(kw_only=True)
class Apple(AppleTree):
  tag : str = "Apple"
  
  def __str__(self):
    return "Apple"

if __name__ == "__main__":
  p1 = Pear()
  p2 = Pear()
  p3 = PearFork(e1=p1, e2=p2)
  print(p3)
  
  a1 = Apple()
  a2 = AppleFork(e=a1)
  print(a2)
  
  # why this work
  ap = AppleFork(e=Pear())
  print(ap)